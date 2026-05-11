import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import UIKit

struct ContentView: View {

    @State private var showPicker = false

    @State private var ipaURL: URL?
    @State private var originalFileName = ""
    @State private var appInfoPlistPath: String?

    @State private var currentBundleID = ""
    @State private var newBundleID = ""
    @State private var displayName = ""
    @State private var duplicateMode = false
    @State private var removeExtensions = false
    @State private var foundExtensions: [String] = []
    @State private var validationMessage = ""

    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var rewrittenExtensions = 0
    @State private var status = "Select an IPA to begin."
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {

                    Text("IPA Bundle ID Editor")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Select IPA") {
                        showPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !currentBundleID.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {

                            Text("Current Bundle ID")
                                .font(.headline)

                            HStack {
                                Text(currentBundleID)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)

                                Spacer()

                                Button {
                                    UIPasteboard.general.string = currentBundleID
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                            }

                            if !appVersion.isEmpty {
                                Text("Version \(appVersion) (\(appBuild))")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Text("New Bundle ID")
                                .font(.headline)
                                .padding(.top, 8)

                            HStack {
                                TextField("com.example.app", text: $newBundleID)
                                    .textFieldStyle(.roundedBorder)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onChange(of: newBundleID) { value in
                                        validationMessage = validateBundleID(value)
                                    }

                                Button {
                                    if let paste = UIPasteboard.general.string {
                                        newBundleID = paste
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                }
                            }

                            Toggle("Duplicate install mode", isOn: $duplicateMode)
                                .onChange(of: duplicateMode) { enabled in
                                    if enabled {
                                        newBundleID = currentBundleID + ".ipaid"
                                    } else {
                                        newBundleID = currentBundleID
                                    }

                                    validationMessage = validateBundleID(newBundleID)
                                }

                            Text("Display Name")
                                .font(.headline)
                                .padding(.top, 8)

                            TextField("App name", text: $displayName)
                                .textFieldStyle(.roundedBorder)

                            if !foundExtensions.isEmpty {
                                Toggle("Remove app extensions before export", isOn: $removeExtensions)

                                Text("\(foundExtensions.count) extension(s) found")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            if !validationMessage.isEmpty {
                                Text(validationMessage)
                                    .font(.callout)
                                    .foregroundStyle(
                                        validationMessage == "Bundle ID looks valid."
                                        ? .green
                                        : .orange
                                    )
                            }

                            Button("Export Updated IPA") {
                                exportUpdatedIPA()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                validateBundleID(newBundleID) != "Bundle ID looks valid."
                                || (newBundleID == currentBundleID
                                    && displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && !removeExtensions)
                            )
                            .padding(.top, 8)

                            if rewrittenExtensions > 0 {
                                Text("\(rewrittenExtensions) extension bundle IDs rewritten")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let exportURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output")
                                .font(.headline)

                            Text(exportURL.lastPathComponent)
                                .font(.system(.callout, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)

                            ShareLink(item: exportURL) {
                                Label("Save / Share Updated IPA", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("IPAID v1.1")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)

                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    handleSelectedFile(url)
                }
            }
        }
    }

    private func handleSelectedFile(_ selected: URL) {
        do {
            originalFileName = selected.lastPathComponent

            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + selected.lastPathComponent)

            if FileManager.default.fileExists(atPath: temp.path) {
                try FileManager.default.removeItem(at: temp)
            }

            let didAccess = selected.startAccessingSecurityScopedResource()

            defer {
                if didAccess {
                    selected.stopAccessingSecurityScopedResource()
                }
            }

            try FileManager.default.copyItem(at: selected, to: temp)

            ipaURL = temp
            exportURL = nil
            rewrittenExtensions = 0
            removeExtensions = false
            duplicateMode = false

            let (path, id, version, build, name, extensions) = try readBundleInfo(from: temp)

            appInfoPlistPath = path
            currentBundleID = id
            newBundleID = id
            displayName = name
            foundExtensions = extensions
            validationMessage = validateBundleID(id)
            appVersion = version
            appBuild = build

            status = "Loaded: \(selected.lastPathComponent)"

        } catch {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)

            status = """
            IPA recommended over ZIP for compatibility.

            Import failed: \(error.localizedDescription)
            """
        }
    }

    private func readBundleInfo(from ipa: URL) throws -> (String, String, String, String, String, [String]) {
        guard let archive = Archive(url: ipa, accessMode: .read) else {
            throw SimpleError("Selected file is not a valid IPA/ZIP archive.")
        }

        guard let entry = archive.first(where: { entry in
            entry.path.hasPrefix("Payload/")
            && entry.path.hasSuffix(".app/Info.plist")
            && !entry.path.contains(".appex/")
        }) else {
            throw SimpleError("Could not find Payload/*.app/Info.plist.")
        }

        let data = try extractData(entry: entry, from: archive)

        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )

        guard let dict = plist as? [String: Any] else {
            throw SimpleError("Invalid Info.plist.")
        }

        guard let id = dict["CFBundleIdentifier"] as? String else {
            throw SimpleError("Info.plist has no CFBundleIdentifier.")
        }

        let version = dict["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = dict["CFBundleVersion"] as? String ?? "Unknown"
        let name =
            dict["CFBundleDisplayName"] as? String
            ?? dict["CFBundleName"] as? String
            ?? ""

        let extensions = archive
            .filter { $0.path.contains(".appex/Info.plist") }
            .map { $0.path }

        return (entry.path, id, version, build, name, extensions)
    }

    private func exportUpdatedIPA() {
        do {
            guard let input = ipaURL else {
                throw SimpleError("No IPA selected.")
            }

            guard let targetPlist = appInfoPlistPath else {
                throw SimpleError("No Info.plist path found.")
            }

            let cleanID = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            let validation = validateBundleID(cleanID)

            guard validation == "Bundle ID looks valid." else {
                throw SimpleError(validation)
            }

            guard let inputArchive = Archive(url: input, accessMode: .read) else {
                throw SimpleError("Could not reopen IPA.")
            }

            let output = makeReadableOutputURL(input: input)

            guard let outputArchive = Archive(url: output, accessMode: .create) else {
                throw SimpleError("Could not create output IPA.")
            }

            rewrittenExtensions = 0

            for entry in inputArchive {
                if entry.type == .directory {
                    continue
                }

                if removeExtensions && entry.path.contains(".appex/") {
                    continue
                }

                var data = try extractData(entry: entry, from: inputArchive)

                let isMainInfoPlist = entry.path == targetPlist

                let isExtensionInfoPlist =
                    entry.path.hasSuffix("Info.plist")
                    && entry.path.contains(".appex/")

                if isMainInfoPlist || isExtensionInfoPlist {
                    let plist = try PropertyListSerialization.propertyList(
                        from: data,
                        options: [],
                        format: nil
                    )

                    guard var dict = plist as? [String: Any] else {
                        throw SimpleError("Could not edit Info.plist.")
                    }

                    if let oldID = dict["CFBundleIdentifier"] as? String {
                        if isMainInfoPlist {
                            dict["CFBundleIdentifier"] = cleanID
                        } else {
                            let lastComponent = oldID.split(separator: ".").last ?? ""
                            dict["CFBundleIdentifier"] = cleanID + "." + lastComponent
                            rewrittenExtensions += 1
                        }
                    }

                    if isMainInfoPlist {
                        let cleanName = displayName
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        if !cleanName.isEmpty {
                            dict["CFBundleDisplayName"] = cleanName
                            dict["CFBundleName"] = cleanName
                        }
                    }

                    data = try PropertyListSerialization.data(
                        fromPropertyList: dict,
                        format: .xml,
                        options: 0
                    )
                }

                try outputArchive.addEntry(
                    with: entry.path,
                    type: .file,
                    uncompressedSize: UInt32(data.count),
                    provider: { position, size -> Data in
                        data.subdata(in: Int(position)..<Int(position) + size)
                    }
                )
            }

            exportURL = output

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            status = "Exported updated IPA. Original file was not replaced."

        } catch {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)

            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private func makeReadableOutputURL(input: URL) -> URL {
        let baseName: String

        if !originalFileName.isEmpty {
            baseName = URL(fileURLWithPath: originalFileName)
                .deletingPathExtension()
                .lastPathComponent
        } else {
            baseName = input
                .deletingPathExtension()
                .lastPathComponent
        }

        let folder = FileManager.default.temporaryDirectory

        var version = 1
        var candidate = folder.appendingPathComponent("\(baseName)-bundlechangedv\(version).ipa")

        while FileManager.default.fileExists(atPath: candidate.path) {
            version += 1
            candidate = folder.appendingPathComponent("\(baseName)-bundlechangedv\(version).ipa")
        }

        return candidate
    }

    private func validateBundleID(_ id: String) -> String {
        let clean = id.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return "Bundle ID cannot be empty."
        }

        if !clean.contains(".") {
            return "Bundle ID must contain at least one dot."
        }

        if clean.contains("..") {
            return "Bundle ID cannot contain two dots in a row."
        }

        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"
        )

        if clean.rangeOfCharacter(from: allowed.inverted) != nil {
            return "Bundle ID contains invalid characters."
        }

        if clean.hasPrefix(".") || clean.hasSuffix(".") {
            return "Bundle ID cannot start or end with a dot."
        }

        return "Bundle ID looks valid."
    }

    private func extractData(entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()

        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }

        return data
    }
}

struct DocumentPicker: UIViewControllerRepresentable {

    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )

        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {

        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                return
            }

            onPick(url)
        }
    }
}

struct SimpleError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
