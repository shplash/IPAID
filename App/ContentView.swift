import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import UIKit

struct ContentView: View {

    @State private var showPicker = false
    @State private var showShareSheet = false

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
    @State private var infoTapLocked = false
    @State private var infoAutoCloseToken = UUID()
    @State private var copiedFilename = false
    @State private var copiedBundleID = false
    @State private var exportSummary = ""
    @State private var validationMessage = ""

    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var rewrittenExtensions = 0
    @State private var status = "Select an IPA to begin."
    @State private var exportURL: URL?

    private var cleanNewBundleID: String {
        newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanCurrentBundleID: String {
        currentBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanOriginalDisplayName: String {
        originalDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedOriginalFileName: String {
        middleTruncated(originalFileName, limit: 34)
    }

    private var bundleIDChanged: Bool {
        !cleanCurrentBundleID.isEmpty && cleanNewBundleID != cleanCurrentBundleID
    }

    private var displayNameChanged: Bool {
        cleanDisplayName != cleanOriginalDisplayName
    }

    private var extensionRemovalChanged: Bool {
        !selectedExtensionsToRemove.isEmpty
    }

    private var hasPendingChanges: Bool {
        bundleIDChanged || displayNameChanged || extensionRemovalChanged
    }

    private var canExport: Bool {
        currentValidationTone != .red && hasPendingChanges
    }

    private enum ValidationTone: Equatable {
        case red
        case orange
        case green
        case none
    }

    private var currentValidationTone: ValidationTone {
        guard !currentBundleID.isEmpty else {
            return .none
        }

        if !validateBundleID(cleanNewBundleID).isEmpty {
            return .red
        }

        if cleanNewBundleID.count > 120 {
            return .red
        }

        if cleanDisplayName.isEmpty {
            return .red
        }

        if cleanDisplayName.count > 30 {
            return .red
        }

        if !hasPendingChanges {
            return .none
        }

        if !bundleIDChanged {
            return .orange
        }

        if extensionRemovalChanged {
            return .orange
        }

        return .green
    }

    private var validationColor: Color {
        switch currentValidationTone {
        case .red:
            return .red
        case .orange:
            return .orange
        case .green:
            return .blue
        case .none:
            return .secondary
        }
    }

    private var currentChangeMessage: String {
        guard !currentBundleID.isEmpty else {
            return ""
        }

        let bundleError = validateBundleID(cleanNewBundleID)
        if !bundleError.isEmpty {
            return bundleError
        }

        if cleanNewBundleID.count > 120 {
            return "Bundle ID is too long."
        }

        if cleanDisplayName.isEmpty {
            return "Display name cannot be empty."
        }

        if cleanDisplayName.count > 30 {
            return "Display name is too long."
        }

        if !hasPendingChanges {
            return "No changes detected."
        }

        if !bundleIDChanged {
            return "Bundle ID unchanged — app may replace the original install."
        }

        if extensionRemovalChanged {
            return "Removing extensions may disable some app functionality."
        }

        return "Ready to export."
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("IPAID")
                                .font(.largeTitle.bold())

                            Text("v1.1")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        if !originalFileName.isEmpty {
                            Text("Loaded: \(displayedOriginalFileName)")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if currentBundleID.isEmpty && !status.isEmpty {
                        Text(status)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 8) {
                        Button("Select IPA") {
                            showPicker = true
                        }
                        .buttonStyle(.borderedProminent)

                        if !currentBundleID.isEmpty {
                            Button {
                                unloadIPA()
                            } label: {
                                Text("Unload")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary.opacity(0.78))
                                    .padding(.vertical, 9)
                                    .padding(.horizontal, 16)
                                    .background(Color.gray.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !currentBundleID.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {

                            Text("Current Bundle ID")
                                .font(.headline.weight(.semibold))

                            HStack {
                                Text(currentBundleID)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .textSelection(.enabled)

                                Spacer()

                                Button {
                                    UIPasteboard.general.string = currentBundleID
                                    copiedBundleID = true

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        copiedBundleID = false
                                    }
                                } label: {
                                    Image(systemName: copiedBundleID ? "checkmark" : "doc.on.doc")
                                }
                            }

                            if !appVersion.isEmpty {
                                Text("v\(appVersion) • build \(appBuild)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }

                            Text("New Bundle ID")
                                .font(.headline.weight(.semibold))
                                .padding(.top, 8)

                            HStack(spacing: 8) {
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
                                        .font(.callout.weight(.semibold))
                                    Spacer()
                                }
                                .padding(.vertical, 11)
                                .padding(.horizontal, 14)
                                .foregroundStyle(duplicateMode ? Color.blue : Color.primary)
                                .background(Color.gray.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)

                            if !foundExtensions.isEmpty {
                                extensionRemovalSection
                            }

                            Text("Display Name")
                                .font(.headline.weight(.semibold))
                                .padding(.top, 2)

                            HStack(spacing: 8) {
                                TextField("App name", text: $displayName)
                                    .font(.body.weight(.regular))
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
                                    .font(.subheadline.weight(.regular))
                                    .foregroundStyle(validationColor)
                                    .padding(.top, 3)
                            }

                            Button("Export Updated IPA") {
                                exportUpdatedIPA()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canExport)
                            .padding(.top, 4)

                            if !status.isEmpty && status.hasPrefix("Export") {
                                Text(status)
                                    .font(.subheadline.weight(.regular))
                                    .foregroundStyle(.secondary)
                            }

                            if !exportSummary.isEmpty {
                                Text(exportSummary)
                                    .font(.subheadline.weight(.regular))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let exportURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Output")
                                .font(.headline.weight(.semibold))

                            Button {
                                UIPasteboard.general.string = exportURL.lastPathComponent
                                copiedFilename = true

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                    copiedFilename = false
                                }
                            } label: {
                                HStack {
                                    Text(exportURL.lastPathComponent)
                                        .font(.callout.weight(.regular))
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

                            Button {
                                showShareSheet = true
                            } label: {
                                Label("Save / Share IPA", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
                .padding()
            }
            .sheet(isPresented: $showPicker) {
                DocumentPicker { url in
                    handleSelectedFile(url)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let exportURL {
                    ActivityView(activityItems: [exportURL])
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var extensionRemovalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    extensionsExpanded.toggle()
                    if !extensionsExpanded {
                        infoAutoCloseToken = UUID()
                        expandedExtensionInfo = nil
                    }
                }
            } label: {
                HStack {
                    Image(systemName: selectedExtensionsToRemove.isEmpty ? "circle" : "checkmark.circle.fill")

                    Text("Extensions • \(selectedExtensionsToRemove.count)/\(foundExtensions.count)")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer()

                    Image(systemName: extensionsExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .foregroundStyle(selectedExtensionsToRemove.isEmpty ? Color.primary : Color.blue)
                .background(Color.gray.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if extensionsExpanded {
                VStack(alignment: .leading, spacing: 6) {
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
                                .font(.body)

                            Text(selectedExtensionsToRemove.count == foundExtensions.count ? "Deselect All" : "Select All")
                                .font(.subheadline.weight(.semibold))

                            Spacer()
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(Color.gray.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)

                    if let infoPath = expandedExtensionInfo {
                        Text(extensionTip(for: extensionName(from: infoPath)))
                            .font(.caption2.weight(.regular))
                            .foregroundStyle(.secondary.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.075))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(7)
                .background(Color.gray.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private func extensionRow(_ path: String) -> some View {
        let isSelected = selectedExtensionsToRemove.contains(path)
        let isExpanded = expandedExtensionInfo == path
        let name = extensionName(from: path)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
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
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(isSelected ? Color.blue : Color.secondary)

                        Text(name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(Color.primary)

                        Spacer(minLength: 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    guard !infoTapLocked else {
                        return
                    }

                    infoTapLocked = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        infoTapLocked = false
                    }

                    if isExpanded {
                        infoAutoCloseToken = UUID()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            expandedExtensionInfo = nil
                        }
                    } else {
                        let token = UUID()
                        infoAutoCloseToken = token

                        withAnimation(.easeInOut(duration: 0.18)) {
                            expandedExtensionInfo = path
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            if infoAutoCloseToken == token && expandedExtensionInfo == path {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    expandedExtensionInfo = nil
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.blue)
                        .frame(width: 40, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

        }
        .font(.subheadline)
        .padding(.vertical, 5)
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .background(isExpanded ? Color.gray.opacity(0.14) : Color.gray.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }


    private func unloadIPA() {
        showShareSheet = false
        ipaURL = nil
        originalFileName = ""
        appInfoPlistPath = nil
        currentBundleID = ""
        newBundleID = ""
        displayName = ""
        originalDisplayName = ""
        duplicateMode = false
        foundExtensions = []
        selectedExtensionsToRemove = []
        extensionsExpanded = false
        expandedExtensionInfo = nil
        infoTapLocked = false
        copiedFilename = false
        copiedBundleID = false
        exportSummary = ""
        validationMessage = ""
        appVersion = ""
        appBuild = ""
        rewrittenExtensions = 0
        exportURL = nil
        status = "Select an IPA to begin."
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
            infoTapLocked = false
            copiedFilename = false
            copiedBundleID = false
            exportSummary = ""
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

            guard validation.isEmpty else {
                throw SimpleError(validation)
            }

            guard canExport else {
                throw SimpleError(currentChangeMessage.isEmpty ? "Nothing changed." : currentChangeMessage)
            }

            guard let inputArchive = Archive(url: input, accessMode: .read) else {
                throw SimpleError("Could not reopen IPA.")
            }

            let output = makeReadableOutputURL(input: input)

            guard let outputArchive = Archive(url: output, accessMode: .create) else {
                throw SimpleError("Could not create output IPA.")
            }

            rewrittenExtensions = 0
            let removedExtensionCount = selectedExtensionsToRemove.count
            let shouldRewriteBundleIDs = bundleIDChanged
            let didChangeName = displayNameChanged
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
                        } else if shouldRewriteBundleIDs {
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
            exportSummary = makeExportSummary(
                bundleIDChanged: shouldRewriteBundleIDs,
                displayNameChanged: didChangeName,
                removedExtensions: removedExtensionCount,
                rewrittenExtensions: rewrittenExtensions
            )
            extensionsExpanded = false
            expandedExtensionInfo = nil

            UINotificationFeedbackGenerator()
                .notificationOccurred(.success)

            status = "Export complete. Original file was not replaced."

        } catch {
            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)

            exportSummary = ""
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

        if clean.isEmpty {
            return "Bundle ID cannot be empty."
        }

        if clean.count > 120 {
            return "Bundle ID is too long."
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

        return ""
    }

    private func makeExportSummary(
        bundleIDChanged: Bool,
        displayNameChanged: Bool,
        removedExtensions: Int,
        rewrittenExtensions: Int
    ) -> String {
        var changes: [String] = []

        if bundleIDChanged {
            changes.append("Bundle ID changed")
        }

        if displayNameChanged {
            changes.append("Display name changed")
        }

        if removedExtensions == 1 {
            changes.append("1 extension removed")
        } else if removedExtensions > 1 {
            changes.append("\(removedExtensions) extensions removed")
        }

        if rewrittenExtensions == 1 {
            changes.append("1 extension ID rewritten")
        } else if rewrittenExtensions > 1 {
            changes.append("\(rewrittenExtensions) extension IDs rewritten")
        }

        guard !changes.isEmpty else {
            return ""
        }

        return "Applied: " + changes.joined(separator: " • ")
    }

    private func clearStaleExportState() {
        guard exportURL != nil || rewrittenExtensions != 0 || status.hasPrefix("Export") else {
            return
        }

        exportURL = nil
        rewrittenExtensions = 0
        exportSummary = ""
        copiedFilename = false
        status = "Changes updated. Export again to create a new IPA."
    }

    private func middleTruncated(_ text: String, limit: Int) -> String {
        guard text.count > limit, limit > 8 else {
            return text
        }

        let keep = max(4, (limit - 1) / 2)
        let start = text.prefix(keep)
        let end = text.suffix(keep)

        return "\(start)…\(end)"
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

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
