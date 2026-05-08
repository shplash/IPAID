import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import UIKit

struct ContentView: View {
    @State private var showPicker = false
    @State private var ipaURL: URL?
    @State private var infoPlistPath: String?

    @State private var currentBundleID = ""
    @State private var newBundleID = ""
    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var exportFileName = ""
    @State private var exportURL: URL?
    @State private var outputFileSize = ""
    @State private var rewrittenExtensions = 0

    @State private var status = "Select an IPA to begin."
    @State private var isExporting = false

    private var canExport: Bool {
        let cleanBundleID = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanExportName = exportFileName.trimmingCharacters(in: .whitespacesAndNewlines)

        return !isExporting
            && !cleanBundleID.isEmpty
            && cleanBundleID != currentBundleID
            && !cleanExportName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header

                    Button("Select IPA") {
                        showPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(isExporting)

                    if !currentBundleID.isEmpty {
                        editor
                    }

                    if let exportURL {
                        outputView(exportURL)
                    }

                    Text("IPAID v1.0.2")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)

                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    loadIPA(url)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("IPA Bundle ID Editor")
                .font(.largeTitle.bold())

            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current Bundle ID")
                .font(.headline)

            copyableText(currentBundleID)

            if !appVersion.isEmpty {
                Text("Version \(appVersion) (\(appBuild))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Text("New Bundle ID")
                .font(.headline)
                .padding(.top, 8)

            editableField(
                placeholder: "com.example.app",
                text: $newBundleID,
                copyButton: false,
                pasteButton: true
            )

            Text("Export Name")
                .font(.headline)
                .padding(.top, 8)

            editableField(
                placeholder: "Output IPA name",
                text: $exportFileName,
                copyButton: true,
                pasteButton: false
            )

            Button(isExporting ? "Exporting…" : "Export Updated IPA") {
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

    private func editableField(
        placeholder: String,
        text: Binding<String>,
        copyButton: Bool,
        pasteButton: Bool
    ) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(isExporting)

            Button {
                text.wrappedValue = ""
            } label: {
                Image(systemName: "xmark.circle")
            }
            .disabled(text.wrappedValue.isEmpty || isExporting)

            if copyButton {
                Button {
                    UIPasteboard.general.string = text.wrappedValue
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(text.wrappedValue.isEmpty)
            }

            if pasteButton {
                Button {
                    newBundleID = UIPasteboard.general.string ?? newBundleID
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .disabled(isExporting)
            }
        }
    }

    private func copyableText(_ value: String) -> some View {
        HStack {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            Button {
                UIPasteboard.general.string = value
            } label: {
                Image(systemName: "doc.on.doc")
            }
        }
    }

    private func outputView(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output")
                .font(.headline)

            Text(outputFileSize.isEmpty ? url.lastPathComponent : "\(url.lastPathComponent) · \(outputFileSize)")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .onTapGesture {
                    UIPasteboard.general.string = url.lastPathComponent
                }

            ShareLink(item: url) {
                Label("Save / Share Updated IPA", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadIPA(_ selectedURL: URL) {
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("ipa")

            let didAccess = selectedURL.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    selectedURL.stopAccessingSecurityScopedResource()
                }
            }

            try FileManager.default.copyItem(at: selectedURL, to: tempURL)

            let bundleInfo = try readBundleInfo(from: tempURL)

            ipaURL = tempURL
            infoPlistPath = bundleInfo.path
            currentBundleID = bundleInfo.bundleID
            newBundleID = bundleInfo.bundleID
            appVersion = bundleInfo.version
            appBuild = bundleInfo.build
            exportFileName = defaultExportFileName(for: selectedURL)
            exportURL = nil
            outputFileSize = ""
            rewrittenExtensions = 0
            isExporting = false
            status = "Loaded: \(selectedURL.lastPathComponent)"
        } catch {
            notify(.error)
            status = "Import failed: \(error.localizedDescription)"
        }
    }

    private func readBundleInfo(from ipa: URL) throws -> BundleInfo {
        guard let archive = Archive(url: ipa, accessMode: .read) else {
            throw SimpleError("Selected file is not a valid IPA/ZIP archive.")
        }

        guard let entry = archive.first(where: {
            $0.path.hasPrefix("Payload/")
                && $0.path.hasSuffix(".app/Info.plist")
                && !$0.path.contains(".appex/")
        }) else {
            throw SimpleError("Could not find Payload/*.app/Info.plist.")
        }

        let plist = try decodePlist(try extractData(entry: entry, from: archive))

        guard let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw SimpleError("Info.plist has no CFBundleIdentifier.")
        }

        return BundleInfo(
            path: entry.path,
            bundleID: bundleID,
            version: plist["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: plist["CFBundleVersion"] as? String ?? "Unknown"
        )
    }

    private func exportUpdatedIPA() {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            guard let inputURL = ipaURL else {
                throw SimpleError("No IPA selected.")
            }

            guard let mainInfoPlistPath = infoPlistPath else {
                throw SimpleError("No Info.plist path found.")
            }

            let cleanBundleID = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanBundleID.contains(".") else {
                throw SimpleError("Bundle ID looks invalid.")
            }

            guard let inputArchive = Archive(url: inputURL, accessMode: .read) else {
                throw SimpleError("Could not reopen IPA.")
            }

            let outputURL = uniqueOutputURL(input: inputURL)
            guard let outputArchive = Archive(url: outputURL, accessMode: .create) else {
                throw SimpleError("Could not create output IPA.")
            }

            rewrittenExtensions = 0

            for entry in inputArchive where entry.type != .directory {
                let updatedData = try updatedEntryData(
                    entry,
                    in: inputArchive,
                    mainInfoPlistPath: mainInfoPlistPath,
                    newBundleID: cleanBundleID
                )

                try outputArchive.addEntry(
                    with: entry.path,
                    type: .file,
                    uncompressedSize: UInt32(updatedData.count),
                    provider: { position, size in
                        updatedData.subdata(in: Int(position)..<Int(position) + size)
                    }
                )
            }

            exportURL = outputURL
            exportFileName = outputURL.lastPathComponent
            outputFileSize = readableFileSize(for: outputURL)
            status = "Exported updated IPA. Original file was not replaced."
            notify(.success)
        } catch {
            status = "Export failed: \(error.localizedDescription)"
            notify(.error)
        }
    }

    private func updatedEntryData(
        _ entry: Entry,
        in archive: Archive,
        mainInfoPlistPath: String,
        newBundleID: String
    ) throws -> Data {
        var data = try extractData(entry: entry, from: archive)
        let isMainInfoPlist = entry.path == mainInfoPlistPath
        let isExtensionInfoPlist = entry.path.hasSuffix("Info.plist") && entry.path.contains(".appex/")

        guard isMainInfoPlist || isExtensionInfoPlist else {
            return data
        }

        var plist = try decodePlist(data)

        if isMainInfoPlist {
            plist["CFBundleIdentifier"] = newBundleID
        } else if let oldBundleID = plist["CFBundleIdentifier"] as? String,
                  let extensionSuffix = oldBundleID.split(separator: ".").last {
            plist["CFBundleIdentifier"] = "\(newBundleID).\(extensionSuffix)"
            rewrittenExtensions += 1
        }

        data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        return data
    }

    private func decodePlist(_ data: Data) throws -> [String: Any] {
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )

        guard let dict = plist as? [String: Any] else {
            throw SimpleError("Invalid Info.plist.")
        }

        return dict
    }

    private func defaultExportFileName(for input: URL) -> String {
        let baseName = input.deletingPathExtension().lastPathComponent
        return "\(baseName)-bundlechangedv1.ipa"
    }

    private func uniqueOutputURL(input: URL) -> URL {
        let folder = FileManager.default.temporaryDirectory
        let cleanName = sanitizedIPAFileName(exportFileName, fallback: defaultExportFileName(for: input))
        var candidate = folder.appendingPathComponent(cleanName)

        guard FileManager.default.fileExists(atPath: candidate.path) else {
            return candidate
        }

        let baseName = candidate.deletingPathExtension().lastPathComponent
        var suffix = 2

        repeat {
            candidate = folder.appendingPathComponent("\(baseName)-\(suffix).ipa")
            suffix += 1
        } while FileManager.default.fileExists(atPath: candidate.path)

        return candidate
    }

    private func sanitizedIPAFileName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawName = trimmed.isEmpty ? fallback : trimmed
        let illegalCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = rawName
            .components(separatedBy: illegalCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))

        let safeName = cleaned.isEmpty ? "UpdatedIPA" : cleaned
        return safeName.lowercased().hasSuffix(".ipa") ? safeName : safeName + ".ipa"
    }

    private func readableFileSize(for url: URL) -> String {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return ""
        }

        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    private func extractData(entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { data.append($0) }
        return data
    }

    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

private struct BundleInfo {
    let path: String
    let bundleID: String
    let version: String
    let build: String
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
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
