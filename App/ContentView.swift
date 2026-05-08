import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import UIKit

struct ContentView: View {

    @State private var showImporter = false

    @State private var ipaURL: URL?
    @State private var originalFileName = ""

    @State private var appInfoPlistPath: String?

    @State private var currentBundleID = ""
    @State private var newBundleID = ""

    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var rewrittenExtensions = 0

    @State private var status = "Select an IPA to begin."

    @State private var exportURL: URL?

    @State private var iconImage: UIImage?

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

                    if let iconImage {

                        Image(uiImage: iconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button("Select IPA") {
                        showImporter = true
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

                                TextField(
                                    "com.example.app",
                                    text: $newBundleID
                                )
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Button {
                                    if let paste = UIPasteboard.general.string {
                                        newBundleID = paste
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                }
                            }

                            Button("Export Updated IPA") {
                                exportUpdatedIPA()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                newBundleID
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )
                                    .isEmpty
                                || newBundleID == currentBundleID
                            )
                            .padding(.top, 8)

                            if rewrittenExtensions > 0 {

                                Text(
                                    "\(rewrittenExtensions) extension bundle IDs rewritten"
                                )
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
                                .textSelection(.enabled)

                            ShareLink(item: exportURL) {
                                Label(
                                    "Save / Share Updated IPA",
                                    systemImage: "square.and.arrow.up"
                                )
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
                .padding()
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {

        do {

            guard let selected = try result.get().first else {
                return
            }

            let didAccess =
                selected.startAccessingSecurityScopedResource()

            defer {
                if didAccess {
                    selected.stopAccessingSecurityScopedResource()
                }
            }

            originalFileName = selected.lastPathComponent

            let temp =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    UUID().uuidString + "-" + selected.lastPathComponent
                )

            if FileManager.default.fileExists(atPath: temp.path) {
                try FileManager.default.removeItem(at: temp)
            }

            try FileManager.default.copyItem(at: selected, to: temp)

            ipaURL = temp
            exportURL = nil
            rewrittenExtensions = 0

            let (path, id, version, build, icon) =
                try readBundleInfo(from: temp)

            appInfoPlistPath = path

            currentBundleID = id
            newBundleID = id

            appVersion = version
            appBuild = build

            iconImage = icon

            status = "Loaded: \(selected.lastPathComponent)"

        } catch {

            status = "Import failed: \(error.localizedDescription)"
        }
    }

    private func readBundleInfo(
        from ipa: URL
    ) throws -> (String, String, String, String, UIImage?) {

        guard let archive = Archive(url: ipa, accessMode: .read) else {
            throw SimpleError("Could not open IPA as ZIP.")
        }

        guard let entry = archive.first(where: { entry in

            entry.path.hasPrefix("Payload/")
            && entry.path.hasSuffix(".app/Info.plist")
            && !entry.path.contains(".appex/")

        }) else {

            throw SimpleError(
                "Could not find Payload/*.app/Info.plist."
            )
        }

        let data = try extractData(entry: entry, from: archive)

        let plist =
            try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )

        guard let dict = plist as? [String: Any] else {
            throw SimpleError("Invalid Info.plist.")
        }

        guard let id = dict["CFBundleIdentifier"] as? String else {
            throw SimpleError(
                "Info.plist has no CFBundleIdentifier."
            )
        }

        let version =
            dict["CFBundleShortVersionString"] as? String ?? "Unknown"

        let build =
            dict["CFBundleVersion"] as? String ?? "Unknown"

        return (
            entry.path,
            id,
            version,
            build,
            nil
        )
    }

    private func exportUpdatedIPA() {

        do {

            guard let input = ipaURL else {
                throw SimpleError("No IPA selected.")
            }

            guard let targetPlist = appInfoPlistPath else {
                throw SimpleError("No Info.plist path found.")
            }

            let cleanID =
                newBundleID
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard cleanID.contains(".") else {
                throw SimpleError("Bundle ID looks invalid.")
            }

            guard let inputArchive =
                Archive(url: input, accessMode: .read)
            else {
                throw SimpleError("Could not reopen IPA.")
            }

            let output =
                makeReadableOutputURL(
                    input: input,
                    bundleID: cleanID
                )

            if FileManager.default.fileExists(atPath: output.path) {
                try FileManager.default.removeItem(at: output)
            }

            guard let outputArchive =
                Archive(url: output, accessMode: .create)
            else {
                throw SimpleError("Could not create output IPA.")
            }

            rewrittenExtensions = 0

            for entry in inputArchive {

                if entry.type == .directory {
                    continue
                }

                var data =
                    try extractData(
                        entry: entry,
                        from: inputArchive
                    )

                let isMainInfoPlist =
                    entry.path == targetPlist

                let isExtensionInfoPlist =
                    entry.path.hasSuffix("Info.plist")
                    && entry.path.contains(".appex/")

                if isMainInfoPlist || isExtensionInfoPlist {

                    let plist =
                        try PropertyListSerialization.propertyList(
                            from: data,
                            options: [],
                            format: nil
                        )

                    guard var dict =
                        plist as? [String: Any]
                    else {
                        throw SimpleError(
                            "Could not edit Info.plist."
                        )
                    }

                    if let oldID =
                        dict["CFBundleIdentifier"] as? String {

                        if isMainInfoPlist {

                            dict["CFBundleIdentifier"] = cleanID

                        } else {

                            let lastComponent =
                                oldID
                                .split(separator: ".")
                                .last ?? ""

                            dict["CFBundleIdentifier"] =
                                cleanID + "." + lastComponent

                            rewrittenExtensions += 1
                        }
                    }

                    data =
                        try PropertyListSerialization.data(
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

                        data.subdata(
                            in: Int(position)..<Int(position) + size
                        )
                    }
                )
            }

            exportURL = output

            currentBundleID = cleanID

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            status =
                "Exported updated IPA. Original file was not replaced."

        } catch {

            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private func makeReadableOutputURL(
        input: URL,
        bundleID: String
    ) -> URL {

        let baseName: String

        if !originalFileName.isEmpty {

            baseName =
                URL(fileURLWithPath: originalFileName)
                .deletingPathExtension()
                .lastPathComponent

        } else {

            baseName =
                input
                .deletingPathExtension()
                .lastPathComponent
        }

        let safeBundleID =
            bundleID
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: " ", with: "")

        let fileName =
            "\(baseName)-bundleid-\(safeBundleID).ipa"

        return
            FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
    }

    private func extractData(
        entry: Entry,
        from archive: Archive
    ) throws -> Data {

        var data = Data()

        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }

        return data
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
