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

    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportProgressText = ""

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
        !cleanCurrentBundleID.isEmpty &&
        cleanNewBundleID != cleanCurrentBundleID
    }

    private var displayNameChanged: Bool {
        cleanDisplayName != cleanOriginalDisplayName
    }

    private var extensionRemovalChanged: Bool {
        !selectedExtensionsToRemove.isEmpty
    }

    private var hasPendingChanges: Bool {
        bundleIDChanged ||
        displayNameChanged ||
        extensionRemovalChanged
    }

    private var canExport: Bool {
        !isExporting &&
        currentValidationTone != .red &&
        hasPendingChanges
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
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        headerSection

                        if currentBundleID.isEmpty {
                            emptyStateSection
                        } else {
                            editorSection
                        }

                        if let exportURL {
                            outputSection(exportURL)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
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

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("IPAID")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("IPA Bundle ID Editor")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("1.2")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !originalFileName.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "doc.zipper")
                        .font(.caption)

                    Text(displayedOriginalFileName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if !currentBundleID.isEmpty {
                        Button("Unload") {
                            unloadIPA()
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyStateSection: some View {
        VStack(spacing: 18) {
            Image(systemName: "shippingbox")
                .font(.system(size: 42))
                .foregroundStyle(.blue)

            VStack(spacing: 5) {
                Text("Choose an IPA")
                    .font(.title3.weight(.bold))

                Text("Load an IPA to inspect and modify its bundle configuration.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showPicker = true
            } label: {
                Label("Select IPA", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var editorSection: some View {
        VStack(spacing: 14) {

            appOverviewCard

            bundleIDCard

            extensionCard

            displayNameCard

            validationCard

            exportCard
        }
    }

    private var appOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                icon: "app.badge",
                title: "App Information"
            )

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName.isEmpty ? "Unnamed App" : displayName)
                        .font(.headline)

                    Text(currentBundleID)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if !appVersion.isEmpty {
                        Text("v\(appVersion)")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text("Build \(appBuild)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private var bundleIDCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            sectionTitle(
                icon: "shippingbox.fill",
                title: "Bundle ID"
            )

            HStack(spacing: 8) {
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
                .buttonStyle(.plain)
            }
            .foregroundStyle(.secondary)

            Divider()

            Text("New Bundle ID")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                TextField(
                    "com.example.app",
                    text: $newBundleID
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

                if !newBundleID.isEmpty {
                    Button {
                        newBundleID = ""
                        duplicateMode = false
                        validationMessage = validateBundleID(newBundleID)
                        clearStaleExportState()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if let paste = UIPasteboard.general.string {
                        newBundleID = paste
                        validationMessage = validateBundleID(paste)
                        clearStaleExportState()
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: newBundleID) { value in
                if duplicateMode &&
                    value != currentBundleID + ".ipaid" {
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
                HStack(spacing: 9) {
                    Image(
                        systemName:
                            duplicateMode
                            ? "checkmark.circle.fill"
                            : "circle"
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clone App")
                            .font(.subheadline.weight(.semibold))

                        Text("Use a different Bundle ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .foregroundStyle(
                    duplicateMode
                    ? Color.blue
                    : Color.primary
                )
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private var extensionCard: some View {
        Group {
            if !foundExtensions.isEmpty {
                extensionRemovalSection
                    .cardStyle()
            }
        }
    }

    private var displayNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            sectionTitle(
                icon: "textformat",
                title: "Display Name"
            )

            HStack(spacing: 8) {
                TextField(
                    "App name",
                    text: $displayName
                )
                .lineLimit(1)

                if !displayName.isEmpty {
                    Button {
                        displayName = ""
                        clearStaleExportState()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if let paste = UIPasteboard.general.string {
                        displayName = paste
                        clearStaleExportState()
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onChange(of: displayName) { _ in
                clearStaleExportState()
            }

            HStack {
                Text("\(cleanDisplayName.count)/30 characters")
                    .font(.caption)
                    .foregroundStyle(
                        cleanDisplayName.count > 30
                        ? .red
                        : .secondary
                    )

                Spacer()
            }
        }
        .cardStyle()
    }

    private var validationCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: validationIcon)
                .foregroundStyle(validationColor)

            Text(currentChangeMessage)
                .font(.subheadline)
                .foregroundStyle(validationColor)

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(validationColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var validationIcon: String {
        switch currentValidationTone {
        case .red:
            return "exclamationmark.triangle.fill"

        case .orange:
            return "exclamationmark.circle.fill"

        case .green:
            return "checkmark.circle.fill"

        case .none:
            return "info.circle"
        }
    }

    private var exportCard: some View {
        VStack(spacing: 12) {

            if isExporting {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("Exporting IPA")
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Text("\(Int(exportProgress * 100))%")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                    }

                    ProgressView(value: exportProgress)
                        .progressViewStyle(.linear)

                    Text(exportProgressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Button {
                exportUpdatedIPA()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                    }

                    Text(
                        isExporting
                        ? "Exporting…"
                        : "Export Updated IPA"
                    )
                    .font(.headline)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canExport)

            if !exportSummary.isEmpty {
                Text(exportSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
    }

    private func outputSection(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            sectionTitle(
                icon: "checkmark.circle.fill",
                title: "Export Ready"
            )

            Button {
                UIPasteboard.general.string = url.lastPathComponent
                copiedFilename = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    copiedFilename = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.zipper")
                        .foregroundStyle(.blue)

                    Text(url.lastPathComponent)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Image(
                        systemName:
                            copiedFilename
                            ? "checkmark"
                            : "doc.on.doc"
                    )
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                showShareSheet = true
            } label: {
                Label(
                    "Save / Share IPA",
                    systemImage: "square.and.arrow.up"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if !status.isEmpty {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private func sectionTitle(
        icon: String,
        title: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)

            Text(title)
                .font(.headline.weight(.bold))
        }
    }

    private var extensionRemovalSection: some View {
        VStack(alignment: .leading, spacing: 10) {

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
                    Image(
                        systemName:
                            selectedExtensionsToRemove.isEmpty
                            ? "puzzlepiece.extension"
                            : "checkmark.circle.fill"
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Extensions")
                            .font(.headline.weight(.semibold))

                        Text(
                            "\(selectedExtensionsToRemove.count) of \(foundExtensions.count) selected"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(
                        systemName:
                            extensionsExpanded
                            ? "chevron.up"
                            : "chevron.down"
                    )
                    .font(.caption.bold())
                }
                .foregroundStyle(
                    selectedExtensionsToRemove.isEmpty
                    ? Color.primary
                    : Color.blue
                )
            }
            .buttonStyle(.plain)

            if extensionsExpanded {
                VStack(alignment: .leading, spacing: 7) {

                    ForEach(foundExtensions, id: \.self) { path in
                        extensionRow(path)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedExtensionsToRemove.count ==
                                foundExtensions.count {
                                selectedExtensionsToRemove = []
                            } else {
                                selectedExtensionsToRemove =
                                    Set(foundExtensions)
                            }

                            clearStaleExportState()
                        }
                    } label: {
                        HStack {
                            Image(
                                systemName:
                                    selectedExtensionsToRemove.count ==
                                    foundExtensions.count
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )

                            Text(
                                selectedExtensionsToRemove.count ==
                                foundExtensions.count
                                ? "Deselect All"
                                : "Select All"
                            )
                            .font(.subheadline.weight(.semibold))

                            Spacer()
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                }
                .padding(9)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
        }
    }

    private func extensionRow(_ path: String) -> some View {
        let isSelected =
            selectedExtensionsToRemove.contains(path)

        let isExpanded =
            expandedExtensionInfo == path

        let name =
            extensionName(from: path)

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
                    HStack(spacing: 9) {
                        Image(
                            systemName:
                                isSelected
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .foregroundStyle(
                            isSelected
                            ? Color.blue
                            : Color.secondary
                        )

                        Text(name)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    toggleExtensionInfo(path)
                } label: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 30)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Text(
                    extensionTip(
                        for: extensionName(from: path)
                    )
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .font(.subheadline)
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            isExpanded
            ? Color.blue.opacity(0.07)
            : Color.secondary.opacity(0.06)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private func toggleExtensionInfo(_ path: String) {
        guard !infoTapLocked else {
            return
        }

        infoTapLocked = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            infoTapLocked = false
        }

        if expandedExtensionInfo == path {
            infoAutoCloseToken = UUID()

            withAnimation(.easeInOut(duration: 0.18)) {
                expandedExtensionInfo = nil
            }

            return
        }

        let token = UUID()
        infoAutoCloseToken = token

        withAnimation(.easeInOut(duration: 0.18)) {
            expandedExtensionInfo = path
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if infoAutoCloseToken == token &&
                expandedExtensionInfo == path {

                withAnimation(.easeInOut(duration: 0.18)) {
                    expandedExtensionInfo = nil
                }
            }
        }
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

        isExporting = false
        exportProgress = 0
        exportProgressText = ""

        status = "Select an IPA to begin."
    }

    private func handleSelectedFile(_ selected: URL) {
        do {
            originalFileName =
                selected.lastPathComponent

            let temp =
                FileManager.default.temporaryDirectory
                    .appendingPathComponent(
                        UUID().uuidString +
                        "-" +
                        selected.lastPathComponent
                    )

            if FileManager.default.fileExists(
                atPath: temp.path
            ) {
                try FileManager.default.removeItem(at: temp)
            }

            let didAccess =
                selected.startAccessingSecurityScopedResource()

            defer {
                if didAccess {
                    selected.stopAccessingSecurityScopedResource()
                }
            }

            try FileManager.default.copyItem(
                at: selected,
                to: temp
            )

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

            let info =
                try readBundleInfo(from: temp)

            appInfoPlistPath = info.path
            currentBundleID = info.id
            newBundleID = info.id

            displayName = info.name
            originalDisplayName = info.name

            foundExtensions = info.extensions

            validationMessage =
                validateBundleID(info.id)

            appVersion = info.version
            appBuild = info.build

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

    private struct BundleInfo {
        let path: String
        let id: String
        let version: String
        let build: String
        let name: String
        let extensions: [String]
    }

    private func readBundleInfo(
        from ipa: URL
    ) throws -> BundleInfo {

        guard let archive =
            Archive(
                url: ipa,
                accessMode: .read
            ) else {
            throw SimpleError(
                "Selected file is not a valid IPA/ZIP archive."
            )
        }

        guard let entry =
            archive.first(where: { entry in

                entry.path.hasPrefix("Payload/") &&
                entry.path.hasSuffix(".app/Info.plist") &&
                !entry.path.contains(".appex/")
            }) else {
            throw SimpleError(
                "Could not find Payload/*.app/Info.plist."
            )
        }

        let data =
            try extractData(
                entry: entry,
                from: archive
            )

        let plist =
            try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )

        guard let dict =
            plist as? [String: Any] else {
            throw SimpleError(
                "Invalid Info.plist."
            )
        }

        guard let id =
            dict["CFBundleIdentifier"] as? String else {
            throw SimpleError(
                "Info.plist has no CFBundleIdentifier."
            )
        }

        let version =
            dict["CFBundleShortVersionString"] as? String
            ?? "Unknown"

        let build =
            dict["CFBundleVersion"] as? String
            ?? "Unknown"

        let name =
            dict["CFBundleDisplayName"] as? String
            ??
            dict["CFBundleName"] as? String
            ??
            ""

        let extensions =
            archive
                .filter {
                    $0.path.contains(".appex/Info.plist")
                }
                .map {
                    $0.path
                }

        return BundleInfo(
            path: entry.path,
            id: id,
            version: version,
            build: build,
            name: name,
            extensions: extensions
        )
    }

    private func exportUpdatedIPA() {
        guard !isExporting else {
            return
        }

        isExporting = true
        exportProgress = 0
        exportProgressText = "Preparing archive…"
        exportURL = nil
        exportSummary = ""

        let input = ipaURL
        let targetPlist = appInfoPlistPath

        let cleanID =
            newBundleID.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let shouldRewriteBundleIDs =
            bundleIDChanged

        let didChangeName =
            displayNameChanged

        let removedExtensionCount =
            selectedExtensionsToRemove.count

        let selectedExtensionRoots =
            selectedExtensionsToRemove.map {
                extensionRoot(from: $0)
            }

        let cleanName =
            displayName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        let originalName =
            originalFileName

        DispatchQueue.global(qos: .userInitiated).async {

            do {
                guard let input else {
                    throw SimpleError("No IPA selected.")
                }

                guard let targetPlist else {
                    throw SimpleError(
                        "No Info.plist path found."
                    )
                }

                let validation =
                    validateBundleID(cleanID)

                guard validation.isEmpty else {
                    throw SimpleError(validation)
                }

                guard let inputArchive =
                    Archive(
                        url: input,
                        accessMode: .read
                    ) else {
                    throw SimpleError(
                        "Could not reopen IPA."
                    )
                }

                let entries =
                    Array(inputArchive)

                let files =
                    entries.filter {
                        $0.type != .directory
                    }

                let output =
                    makeReadableOutputURL(
                        input: input,
                        originalName: originalName
                    )

                guard let outputArchive =
                    Archive(
                        url: output,
                        accessMode: .create
                    ) else {
                    throw SimpleError(
                        "Could not create output IPA."
                    )
                }

                var rewrittenCount = 0
                var processed = 0

                for entry in files {

                    if selectedExtensionRoots.contains(
                        where: {
                            entry.path.hasPrefix($0)
                        }
                    ) {
                        processed += 1

                        updateExportProgress(
                            progress:
                                Double(processed) /
                                Double(max(files.count, 1)),
                            text: "Removing extension…"
                        )

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
                        entry.path.hasSuffix("Info.plist") &&
                        entry.path.contains(".appex/")

                    if isMainInfoPlist ||
                        isExtensionInfoPlist {

                        let plist =
                            try PropertyListSerialization
                                .propertyList(
                                    from: data,
                                    options: [],
                       
