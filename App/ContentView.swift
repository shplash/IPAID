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
    @State private var originalDisplayName = ""
    @State private var duplicateMode = false
    @State private var foundExtensions: [String] = []
    @State private var selectedExtensionsToRemove: Set<String> = []
    @State private var extensionsExpanded = false
    @State private var validationMessage = ""

    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var rewrittenExtensions = 0
    @State private var status = "Select an IPA to begin."
    @State private var exportURL: URL?

    private var canExport: Bool {
        let cleanID = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOriginalName = originalDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let validation = validateBundleID(cleanID)
        let sameBundleID = cleanID == currentBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = cleanName != cleanOriginalName
        let extensionChanges = !selectedExtensionsToRemove.isEmpty

        if validation == "Bundle ID looks valid." {
            return !sameBundleID || nameChanged || extensionChanges
        }

        if validation == "Bundle ID is the same as the original." {
            return nameChanged || extensionChanges
        }

        return false
    }

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
                                        if duplicateMode && value != currentBundleID + ".ipaid" {
                                            duplicateMode = false
                                        }

                                        validationMessage = validateBundleID(value)
                                    }

                                Button {
                                    newBundleID = ""
                                    validationMessage = validateBundleID(newBundleID)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }

                                Button {
                                    if let paste = UIPasteboard.general.string {
                                        newBundleID = paste
                                        validationMessage = validateBundleID(paste)
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                }
                            }

                            Button {
                                duplicateMode.toggle()

                                if duplicateMode {
                                    newBundleID = currentBundleID + ".ipaid"
                                } else {
                                    newBundleID = currentBundleID
                                }

                                validationMessage = validateBundleID(newBundleID)
                            } label: {
                                HStack {
                                    Image(systemName: duplicateMode ? "checkmark.circle.fill" : "circle")
                                    Text("Clone App")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 14)
                                .foregroundStyle(duplicateMode ? Color.white : Color.primary)
                                .background(duplicateMode ? Color.blue : Color.gray.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)

                            Text("Display Name")
                                .font(.headline)
                                .padding(.top, 8)

                            HStack {
                                TextField("App name", text: $displayName)
                                    .textFieldStyle(.roundedBorder)

                                Button {
                                    displayName = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }

                                Button {
                                    if let paste = UIPasteboard.general.string {
                                        displayName = paste
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                }
                            }

                            if !foundExtensions.isEmpty {
                                extensionRemovalSection
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
                            .disabled(!canExport)
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

    private var extensionRemovalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    extensionsExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: selectedExtensionsToRemove.isEmpty ? "circle" : "checkmark.circle.fill")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove Extensions")
                            .fontWeight(.semibold)

                        Text("\(selectedExtensionsToRemove.count) of \(foundExtensions.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: extensionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .foregroundStyle(selectedExtensionsToRemove.isEmpty ? Color.primary : Color.white)
                .background(selectedExtensionsToRemove.isEmpty ? Color.gray.opacity(0.18) : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if extensionsExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("Remove All") {
                            selectedExtensionsToRemove = Set(foundExtensions)
                        }
                        .font(.caption.bold())

                        Button("Keep All") {
                            selectedExtensionsToRemove = []
                        }
                        .font(.caption.bold())
                    }

                    ForEach(foundExtensions, id: \.self) { path in
                        Button {
                            if selectedExtensionsToRemove.contains(path) {
                                selectedExtensionsToRemove.remove(path)
                            } else {
                                selectedExtensionsToRemove.insert(path)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedExtensionsToRemove.contains(path) ? "checkmark.circle.fill" : "circle")

                                Text(extensionName(from: path))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()
                            }
                            .font(.callout)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
            selectedExtensionsToRemove = []
            extensionsExpanded = false
            duplicateMode = false

            let (path, id, version, build, name, extensions) = try readBundleInfo(from: temp)

            appInfoPlistPath = path
            currentBundleID = id
            newBundleID = id
            displayName = name
            originalDisplayName = name
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

            guard validation == "Bundle ID looks valid."
                || validation == "Bundle ID is the same as the original."
            else {
                throw SimpleError(validation)
            }

            guard canExport else {
                throw SimpleError("Nothing changed.")
            }

            guard let inputArchive = Archive(url: input, accessMode: .read) else {
                throw SimpleError("Could not reopen IPA.")
            }

            let output = makeReadableOutputURL(input: input)

            guard let outputArchive = Archive(url: output, accessMode: .create) else {
                throw SimpleError("Could not create output IPA.")
            }

            rewrittenExtensions = 0
            let selectedExtensionRoots = selectedExtensionsToRemove.map { extensionRoot(from: $0) }

            for entry in inputArchive {
                if entry.type == .directory {
                    continue
                }

                if selectedExtensionRoots.contains(where: { entry.path.hasPrefix($0) }) {
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
        var candidate = folder.appendingPathComponent("\(baseName)-bid\(version).ipa")

        while FileManager.default.fileExists(atPath: candidate.path) {
            version += 1
            candidate = folder.appendingPathComponent("\(baseName)-bid\(version).ipa")
        }

        return candidate
    }

    private func validateBundleID(_ id: String) -> String {
        let clean = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = currentBundleID.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            return "Bundle ID cannot be empty."
        }

        if !original.isEmpty && clean == original {
            return "Bundle ID is the same as the original."
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

    private func extensionName(from path: String) -> String {
        let parts = path.split(separator: "/").map(String.init)

        if let appExtension = parts.first(where: { $0.hasSuffix(".appex") }) {
            return appExtension.replacingOccurrences(of: ".appex", with: "")
        }

        return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    private func extensionRoot(from infoPlistPath: String) -> String {
        guard let range = infoPlistPath.range(of: ".appex/") else {
            return infoPlistPath
        }

        return String(infoPlistPath[..<range.upperBound])
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
