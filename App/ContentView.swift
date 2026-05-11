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
    @State private var expandedExtensionInfo: String?
    @State private var copiedFilename = false
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

    private var currentChangeMessage: String {
        guard !currentBundleID.isEmpty else {
            return ""
        }

        let cleanID = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanOriginalName = originalDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let validation = validateBundleID(cleanID)
        let sameBundleID = cleanID == currentBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameChanged = cleanName != cleanOriginalName
        let extensionChanges = !selectedExtensionsToRemove.isEmpty

        if validation != "Bundle ID looks valid."
            && validation != "Bundle ID is the same as the original." {
            return validation
        }

        if sameBundleID && !nameChanged && !extensionChanges {
            return "No changes detected."
        }

        if sameBundleID {
            return "Bundle ID unchanged — app may replace the original install."
        }

        return "Bundle ID looks valid."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("IPAID")
                            .font(.title.bold())

                        Text("Modify bundle identifiers, app names, and extensions.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !originalFileName.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Loaded IPA")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            Text(originalFileName)
                                .font(.callout)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !status.isEmpty {
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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

                            HStack(spacing: 10) {
                                TextField("com.example.app", text: $newBundleID)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)

                                Button {
                                    newBundleID = ""
                                    validationMessage = validateBundleID(newBundleID)
                                    clearStaleExportState()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }

                                Button {
                                    if let paste = UIPasteboard.general.string {
                                        newBundleID = paste
                                        validationMessage = validateBundleID(paste)
                                        clearStaleExportState()
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                }
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 14)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .onChange(of: newBundleID) { value in
                                if duplicateMode && value != currentBundleID + ".ipaid" {
                                    duplicateMode = false
                                }

                                validationMessage = validateBundleID(value)
                                clearStaleExportState()
                            }

                            Button {
                                duplicateMode.toggle()

                                if duplicateMode {
                                    newBundleID = currentBundleID + ".ipaid"
                                } else {
                                    newBundleID = currentBundleID
                                }

                                validationMessage = validateBundleID(newBundleID)
                                clearStaleExportState()
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

                            if !foundExtensions.isEmpty {
                                extensionRemovalSection
                            }

                            Text("Display Name")
                                .font(.headline)
                                .padding(.top, 8)

                            HStack(spacing: 10) {
                                TextField("App name", text: $displayName)
                                    .lineLimit(1)

                                Button {
                                    displayName = ""
                                    clearStaleExportState()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }

                                Button {
                                    if let paste = UIPasteboard.general.string {
                                        displayName = paste
                                        clearStaleExportState()
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                }
                            }
                            .padding(.vertical, 13)
                            .padding(.horizontal, 14)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .onChange(of: displayName) { _ in
                                clearStaleExportState()
                            }

                            if !currentChangeMessage.isEmpty {
                                Text(currentChangeMessage)
                                    .font(.callout)
                                    .foregroundStyle(
                                        currentChangeMessage == "Bundle ID looks valid."
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

                            Button {
                                UIPasteboard.general.string = exportURL.lastPathComponent
                                copiedFilename = true

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                    copiedFilename = false
                                }
                            } label: {
                                HStack {
                                    Text(exportURL.lastPathComponent)
                                        .font(.system(.callout, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()

                                    Image(systemName: copiedFilename ? "checkmark" : "doc.on.doc")
                                }
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            if copiedFilename {
                                Text("Copied filename")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

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
                    if !extensionsExpanded {
                        expandedExtensionInfo = nil
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedExtensionsToRemove.isEmpty ? "circle" : "checkmark.circle.fill")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove Extensions")
                            .fontWeight(.semibold)

                        Text("\(selectedExtensionsToRemove.count) of \(foundExtensions.count) selected")
                            .font(.caption)
                            .foregroundStyle(selectedExtensionsToRemove.isEmpty ? Color.secondary : Color.white.opacity(0.85))
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
                    ForEach(foundExtensions, id: \.self) { path in
                        extensionRow(path)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedExtensionsToRemove.count == foundExtensions.count {
                                selectedExtensionsToRemove = []
                            } else {
                                selectedExtensionsToRemove = Set(foundExtensions)
                            }
                            clearStaleExportState()
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedExtensionsToRemove.count == foundExtensions.count ? "checkmark.circle.fill" : "circle")
                                .font(.title3)

                            Text(selectedExtensionsToRemove.count == foundExtensions.count ? "Deselect All Extensions" : "Select All Extensions")
                                .fontWeight(.semibold)

                            Spacer()
                        }
                        .font(.callout)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.gray.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func extensionRow(_ path: String) -> some View {
        let isSelected = selectedExtensionsToRemove.contains(path)
        let isExpanded = expandedExtensionInfo == path
        let name = extensionName(from: path)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if isSelected {
                            selectedExtensionsToRemove.remove(path)
                        } else {
                            selectedExtensionsToRemove.insert(path)
                        }
                        clearStaleExportState()
                    }
                } label: {
                    Text(name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        expandedExtensionInfo = isExpanded ? nil : path
                    }

                    if !isExpanded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            if expandedExtensionInfo == path {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedExtensionInfo = nil
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.blue)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Text(extensionTip(for: name))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .font(.callout)
        .padding(.vertical, isExpanded ? 11 : 9)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            expandedExtensionInfo = nil
            copiedFilename = false
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

            status = ""

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

            status = "Export complete. Original file was not replaced."

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

    private func clearStaleExportState() {
        guard exportURL != nil || rewrittenExtensions != 0 || status.hasPrefix("Export") else {
            return
        }

        exportURL = nil
        rewrittenExtensions = 0
        copiedFilename = false
        status = "Changes updated. Export again to create a new IPA."
    }

    private func extensionName(from path: String) -> String {
        let parts = path.split(separator: "/").map(String.init)
        let rawName: String

        if let appExtension = parts.first(where: { $0.hasSuffix(".appex") }) {
            rawName = appExtension.replacingOccurrences(of: ".appex", with: "")
        } else {
            rawName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        }

        return humanReadableExtensionName(rawName)
    }

    private func humanReadableExtensionName(_ raw: String) -> String {
        var name = raw

        if name.hasSuffix("Extension") {
            name.removeLast("Extension".count)
        }

        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.replacingOccurrences(of: "-", with: " ")

        var result = ""
        var previousWasLowercaseOrNumber = false

        for character in name {
            let scalar = String(character)
            let isUppercase = scalar.rangeOfCharacter(from: .uppercaseLetters) != nil
            let isNumber = scalar.rangeOfCharacter(from: .decimalDigits) != nil

            if isUppercase && previousWasLowercaseOrNumber && !result.hasSuffix(" ") {
                result.append(" ")
            }

            result.append(character)
            previousWasLowercaseOrNumber = scalar.rangeOfCharacter(from: .lowercaseLetters) != nil || isNumber
        }

        let cleaned = result
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? raw : cleaned
    }

    private func extensionTip(for name: String) -> String {
        let lower = name.lowercased()

        if lower.contains("widget") {
            return "Adds Home Screen or Lock Screen widget support. Removing it disables that widget."
        }

        if lower.contains("intent") || lower.contains("siri") {
            return "Handles Siri, Shortcuts, or App Intent actions. Removing it may disable automation features."
        }

        if lower.contains("notification service") {
            return "Handles enhanced notification content, images, or media. Removing it may make notifications more basic."
        }

        if lower.contains("notification content") {
            return "Provides custom notification layouts. Removing it may disable rich notification views."
        }

        if lower.contains("notification") {
            return "Supports notification-related features. Removing it may affect alerts or notification previews."
        }

        if lower.contains("safari") {
            return "Adds Safari integration. Removing it may disable Safari extension features."
        }

        if lower.contains("share") {
            return "Adds Share Sheet integration. Removing it may stop the app appearing in share menus."
        }

        if lower.contains("watch") {
            return "Adds Apple Watch support. Removing it may disable watchOS companion features."
        }

        return "App extension component. Removing it can reduce signing/App ID usage, but some app features may stop working."
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
