import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

struct ContentView: View {
    @State private var showImporter = false
    @State private var ipaURL: URL?
    @State private var appInfoPlistPath: String?
    @State private var currentBundleID = ""
    @State private var newBundleID = ""
    @State private var status = "Select an IPA to begin."
    @State private var exportURL: URL?

    private var ipaType: UTType {
        UTType(filenameExtension: "ipa") ?? .zip
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("IPA Bundle ID Editor")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(status)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Select IPA") {
                    showImporter = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .leading)

                if !currentBundleID.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Bundle ID")
                            .font(.headline)
                        Text(currentBundleID)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)

                        Text("New Bundle ID")
                            .font(.headline)
                            .padding(.top, 8)

                        TextField("com.example.app", text: $newBundleID)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("Export Updated IPA") {
                            exportUpdatedIPA()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Save / Share Updated IPA", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [ipaType, .zip],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let selected = try result.get().first else { return }

            let didAccess = selected.startAccessingSecurityScopedResource()
            defer {
                if didAccess { selected.stopAccessingSecurityScopedResource() }
            }

            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + selected.lastPathComponent)

            if FileManager.default.fileExists(atPath: temp.path) {
                try FileManager.default.removeItem(at: temp)
            }
            try FileManager.default.copyItem(at: selected, to: temp)

            ipaURL = temp
            exportURL = nil

            let (path, id) = try readBundleID(from: temp)
            appInfoPlistPath = path
            currentBundleID = id
            newBundleID = id

            status = "Loaded: \(selected.lastPathComponent)"
        } catch {
            status = "Import failed: \(error.localizedDescription)"
        }
    }

    private func readBundleID(from ipa: URL) throws -> (String, String) {
        guard let archive = Archive(url: ipa, accessMode: .read) else {
            throw SimpleError("Could not open IPA as ZIP.")
        }

        guard let entry = archive.first(where: { entry in
            entry.path.hasPrefix("Payload/")
            && entry.path.hasSuffix(".app/Info.plist")
            && !entry.path.contains(".appex/")
        }) else {
            throw SimpleError("Could not find Payload/*.app/Info.plist.")
        }

        let data = try extractData(entry: entry, from: archive)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard
            let dict = plist as? [String: Any],
            let id = dict["CFBundleIdentifier"] as? String
        else {
            throw SimpleError("Info.plist has no CFBundleIdentifier.")
        }

        return (entry.path, id)
    }

    private func exportUpdatedIPA() {
        do {
            guard let input = ipaURL else { throw SimpleError("No IPA selected.") }
            guard let targetPlist = appInfoPlistPath else { throw SimpleError("No Info.plist path found.") }

            let cleanID = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanID.contains(".") else {
                throw SimpleError("Bundle ID looks invalid.")
            }

            guard let inputArchive = Archive(url: input, accessMode: .read) else {
                throw SimpleError("Could not reopen IPA.")
            }

            let output = FileManager.default.temporaryDirectory
                .appendingPathComponent("Updated-" + input.deletingPathExtension().lastPathComponent + ".ipa")

            if FileManager.default.fileExists(atPath: output.path) {
                try FileManager.default.removeItem(at: output)
            }

            guard let outputArchive = Archive(url: output, accessMode: .create) else {
                throw SimpleError("Could not create output IPA.")
            }

            for entry in inputArchive {
                if entry.type == .directory { continue }

                var data = try extractData(entry: entry, from: inputArchive)

                if entry.path == targetPlist {
                    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                    guard var dict = plist as? [String: Any] else {
                        throw SimpleError("Could not edit Info.plist.")
                    }
                    dict["CFBundleIdentifier"] = cleanID
                    data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
                }

                try outputArchive.addEntry(
                    with: entry.path,
                    type: .file,
                    uncompressedSize: UInt32(data.count),
                    provider: { position, size -> Data in
                        return data.subdata(in: Int(position)..<Int(position) + size)
                    }
                )
            }

            exportURL = output
            currentBundleID = cleanID
            status = "Exported updated IPA. Use the share button to save it to Files or send to SideStore."
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private func extractData(entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }
}

struct SimpleError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }

    var errorDescription: String? {
        message
    }
}
