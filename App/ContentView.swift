import SwiftUI
import Foundation
import UIKit

struct ContentView: View {

    @State private var activeSheet: ActiveSheet?
    @State private var showInfo = false
    @AppStorage("ipaidAppearance") private var appearanceMode = "system"
    @AppStorage("ipaidToolsExpanded") private var toolsExpanded = true
    @AppStorage("ipaidExportSuffix") private var exportSuffix = IPAFormatting.defaultExportSuffix
    @AppStorage("ipaidSkipReview") private var skipReview = false
    @State private var ipaURL: URL?
    @State private var originalFileName = ""

    @State private var currentBundleID = ""
    @State private var newBundleID = ""
    @State private var bundleIDExpanded = true

    @State private var displayName = ""
    @State private var displayNameExpanded = false

    @State private var originalURLScheme = ""
    @State private var newURLScheme = ""

    @State private var duplicateMode = false

    @State private var foundExtensions: [String] = []
    @State private var selectedExtensionsToRemove: Set<String> = []
    @State private var extensionsExpanded = false
    @State private var expandedExtensionInfo: String?

    @State private var infoTapLocked = false
    @State private var infoAutoCloseToken = UUID()

    @State private var copiedBundleID = false

    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var exportURL: URL?
    @State private var exportFileName = ""
    @State private var exportSummary = ""
    @State private var exportedSummary: IPAModificationSummary?
    @State private var exportReviewExpanded = false
    @State private var editedFiles: [String: Data] = [:]
    @State private var inputFileSize: Int64 = 0
    @State private var outputFileSize: Int64 = 0
    @State private var lastExportSignature: String?

    @State private var isExporting = false
    @State private var exportProgress: Double = 0
    @State private var exportProgressText = ""

    @State private var info: IPABundleInfo?
    @State private var entries: [IPAEntry] = []
    @State private var session: IPASession?
    @State private var originalPlist: [String: Any] = [:]

    @State private var newVersion = ""
    @State private var newBuild = ""
    @State private var versionReferences: [IPAVersionReference] = []

    @State private var originalIconData: Data?
    @State private var replacementImage: UIImage?
    @State private var replacementIconName = ""
    @State private var replacementIconFiles: [String: Data] = [:]
    @State private var iconHint: String?
    @State private var iconErrorMessage: String?
    @State private var iconExpanded = false

    @State private var plistOverrides = InfoPlistOverrides()

    @State private var errorMessage: String?
    @State private var isImporting = false

    private var cleanNewBundleID: String {
        newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanCurrentBundleID: String {
        currentBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedOriginalFileName: String {
        IPAFormatting.middleTruncated(originalFileName, limit: 34)
    }

    private var bundleIDChanged: Bool {
        !cleanCurrentBundleID.isEmpty &&
        cleanNewBundleID != cleanCurrentBundleID
    }

    private var bundleIDProblem: String {
        guard bundleIDChanged else {
            return ""
        }

        return MetadataValidation.bundleIdentifier(cleanNewBundleID)
    }

    private var cleanURLScheme: String {
        newURLScheme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var originalIconImage: UIImage? {
        originalIconData.flatMap(UIImage.init(data:))
    }

    private var currentModifications: IPAModifications {
        var modifications = IPAModifications(
            bundleIdentifier: newBundleID,
            displayName: displayName,
            marketingVersion: newVersion,
            buildNumber: newBuild,
            urlScheme: newURLScheme
        )

        modifications.removedExtensions = selectedExtensionsToRemove
        modifications.plistOverrides = plistOverrides
        modifications.editedFiles = editedFiles

        if replacementImage != nil, !replacementIconFiles.isEmpty {
            modifications.icon = IPAIconReplacement(
                imageName: replacementIconName.isEmpty ? "Image" : replacementIconName,
                previewData: Data(),
                files: replacementIconFiles
            )
        }

        return modifications
    }

    private var currentSummary: IPAModificationSummary? {
        guard let info else { return nil }

        return IPAModificationSummary(
            info: info,
            entries: entries,
            modifications: currentModifications
        )
    }

    private var extensionRemovalChanged: Bool {
        !selectedExtensionsToRemove.isEmpty
    }

    private var hasPendingChanges: Bool {
        guard let info, currentModifications.hasChanges(from: info) else {
            return false
        }

        if let lastExportSignature, exportURL != nil {
            return currentModifications.fingerprint != lastExportSignature
        }

        return true
    }

    private var canExport: Bool {
        info != nil &&
        !isExporting &&
        !isImporting &&
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
        guard let info else {
            return .none
        }

        if !currentModifications.problems(comparedTo: info).isEmpty {
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

    private var exportStatusMessage: String {
        guard let info else {
            return ""
        }

        if let problem = currentModifications.problems(comparedTo: info).first {
            return problem == bundleIDProblem ? "" : problem
        }

        guard hasPendingChanges else {
            return ""
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
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)

                    GeometryReader { proxy in
                        ZStack {
                            mainContent
                                .frame(width: proxy.size.width)
                                .offset(x: showInfo ? -proxy.size.width : 0)

                            infoContent
                                .frame(width: proxy.size.width)
                                .offset(x: showInfo ? 0 : proxy.size.width)
                        }
                        .clipped()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .picker:
                    DocumentPicker(
                        onPick: { url in
                            activeSheet = nil
                            handleSelectedFile(url)
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )

                case .share:
                    if let exportURL {
                        ActivityView(activityItems: [exportURL])
                    }

                case .inspector:
                    if let info {
                        IPAInfoSheet(
                            info: info,
                            fileName: originalFileName,
                            iconImage: originalIconImage,
                            onClose: { activeSheet = nil }
                        )
                    }

                case .version:
                    if info != nil {
                        VersionEditorView(
                            marketingVersion: $newVersion,
                            buildNumber: $newBuild,
                            originalVersion: appVersion,
                            originalBuild: appBuild,
                            references: versionReferences,
                            onChange: clearStaleExportState,
                            onClose: { activeSheet = nil }
                        )
                    }

                case .urlScheme:
                    if info != nil {
                        URLEditorView(
                            scheme: $newURLScheme,
                            originalScheme: originalURLScheme,
                            onChange: clearStaleExportState,
                            onClose: { activeSheet = nil }
                        )
                    }

                case .browser:
                    if let ipaURL {
                        FileBrowserView(
                            ipaURL: ipaURL,
                            editedFiles: $editedFiles,
                            onClose: { activeSheet = nil }
                        )
                    }

                case .plistEditor:
                    if let info {
                        AdvancedPlistView(
                            info: info,
                            original: originalPlist,
                            overrides: $plistOverrides,
                            onClose: { activeSheet = nil }
                        )
                    }

                case .comparison:
                    if let ipaURL {
                        ComparisonView(
                            primaryURL: ipaURL,
                            primaryName: originalFileName,
                            onClose: { activeSheet = nil }
                        )
                    }

                case .presets:
                    if let info {
                        PresetsView(
                            info: info,
                            modifications: currentModifications,
                            onApply: applyPreset,
                            onClose: { activeSheet = nil }
                        )
                    }

                case .modificationPreview:
                    if let summary = currentSummary {
                        ModificationPreviewView(
                            summary: summary,
                            originalIcon: originalIconImage,
                            replacementIcon: replacementImage,
                            isExporting: isExporting,
                            onExport: {
                                activeSheet = nil
                                performExport()
                            },
                            onClose: { activeSheet = nil }
                        )
                    }

                case .iconPhotos:
                    PhotoLibraryPicker { image in
                        activeSheet = nil

                        if let image {
                            applyIcon(image, name: "Photo")
                        }
                    }

                case .iconFiles:
                    ImageFilePicker { url in
                        activeSheet = nil

                        if let url {
                            loadIconFile(url)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(selectedColorScheme)
        .onAppear {
            IPATemporaryStore.pruneSessions(keeping: session?.directory)
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !originalFileName.isEmpty, exportURL == nil {
                    fileInfoSection
                }

                if isImporting {
                    IPALoadingRow(text: "Reading IPA…")
                }

                if let errorMessage {
                    IPAInfoBanner(
                        message: errorMessage,
                        color: .red,
                        onDismiss: { self.errorMessage = nil }
                    )
                }

                if currentBundleID.isEmpty {
                    emptyStateSection
                } else if exportURL != nil {
                    outputSection
                } else {
                    editorSection
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }

    private var infoContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                InfoView(
                    currentVersion: currentAppVersion,
                    currentBuild: currentAppBuild,
                    appearanceMode: $appearanceMode,
                    exportSuffix: $exportSuffix,
                    skipReview: $skipReview
                )
                Spacer(minLength: 34)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
    }

    private var fileInfoSection: some View {
        HStack(spacing: 7) {
            Image(systemName: "doc.zipper")
                .font(.footnote)

            Text(displayedOriginalFileName)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !currentBundleID.isEmpty {
                Button("Unload") {
                    unloadIPA()
                }
                .font(.footnote.weight(.semibold))
                .disabled(isExporting)
            }
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var currentAppVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown"
    }

    private var currentAppBuild: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? ""
    }

    private var selectedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(alignment: .bottom, spacing: 3) {
                Text("IPAID")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("v\(currentAppVersion)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 6)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                if !showInfo {
                    headerButton(icon: "slider.horizontal.3", action: openPresets)
                        .disabled(info == nil)
                        .opacity(info == nil ? 0.45 : 1)
                }

                headerButton(
                    icon: showInfo ? "xmark" : "gearshape.fill",
                    action: toggleSettings
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 38, height: 38)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func openPresets() {
        guard info != nil else {
            return
        }

        activeSheet = .presets
    }

    private func toggleSettings() {
        withAnimation(.easeInOut(duration: 0.28)) {
            showInfo.toggle()
        }
    }

    private var emptyStateSection: some View {
        VStack(spacing: 18) {
            Image(systemName: "shippingbox")
                .font(.system(size: 42))
                .foregroundColor(.blue)

            VStack(spacing: 5) {
                Text("Choose an IPA")
                    .font(.title3.weight(.bold))

                Text("Load an IPA to inspect and modify its bundle configuration.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                activeSheet = .picker
            } label: {
                Label("Select IPA", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .ipaidProminentButton()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var editorSection: some View {
        VStack(spacing: 14) {

            appOverviewCard

            bundleIDCard

            displayNameCard

            iconCard

            extensionCard

            toolsCard

            exportCard
        }
    }

    private func toggleTools() {
        withAnimation(.easeInOut(duration: 0.2)) {
            toolsExpanded = !toolsExpanded
        }
    }

    private var appOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            IPACardHeader(icon: "app.badge", title: "App Information")

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(originalAppName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if !originalVersionLabel.isEmpty {
                        Text(originalVersionLabel)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    if !originalBuildLabel.isEmpty {
                        Text(originalBuildLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .cardStyle()
    }

    private var originalAppName: String {
        guard let info, !info.displayName.isEmpty else {
            return "Unnamed App"
        }

        return info.displayName
    }

    private var originalVersionLabel: String {
        IPAFormatting.versionLabel(info?.marketingVersion ?? appVersion)
    }

    private var originalBuildLabel: String {
        IPAFormatting.buildLabel(info?.buildNumber ?? appBuild)
    }

    private var bundleIDCard: some View {
        IPAExpandableCard(
            icon: "shippingbox.fill",
            title: "Bundle ID",
            trailingText: cleanNewBundleID.isEmpty ? MetadataValidation.cannotBeEmpty : nil,
            trailingColor: .red,
            isExpanded: $bundleIDExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                IPAFieldBox {
                    HStack(spacing: 10) {
                        TextField(
                            "com.example.app",
                            text: $newBundleID
                        )
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)

                        Button {
                            if cleanNewBundleID.isEmpty {
                                if let paste = UIPasteboard.general.string {
                                    newBundleID = paste
                                    duplicateMode = false
                                    clearStaleExportState()
                                }
                            } else {
                                UIPasteboard.general.string = cleanNewBundleID
                                copiedBundleID = true

                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    copiedBundleID = false
                                }
                            }
                        } label: {
                            Image(systemName: fieldButtonIcon)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        if !newBundleID.isEmpty {
                            Button {
                                newBundleID = ""
                                duplicateMode = false
                                clearStaleExportState()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .onChange(of: newBundleID) { value in
                    if duplicateMode &&
                        value != currentBundleID + ".ipaid" {
                        duplicateMode = false
                    }

                    clearStaleExportState()
                }

                if bundleIDChanged {
                    Text("Original \(currentBundleID)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if !cleanNewBundleID.isEmpty, !bundleIDProblem.isEmpty {
                    Text(bundleIDProblem)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    duplicateMode.toggle()

                    if duplicateMode {
                        newBundleID = currentBundleID + ".ipaid"
                    } else {
                        newBundleID = currentBundleID
                    }

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
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .foregroundColor(
                        duplicateMode
                        ? Color.blue
                        : Color.primary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var fieldButtonIcon: String {
        if cleanNewBundleID.isEmpty {
            return "doc.on.clipboard"
        }

        return copiedBundleID ? "checkmark" : "doc.on.doc"
    }

    private var extensionCard: some View {
        Group {
            if !foundExtensions.isEmpty {
                IPAExpandableCard(
                    icon: "puzzlepiece.extension",
                    title: "Extensions",
                    subtitle: extensionsSubtitle,
                    isExpanded: extensionsBinding
                ) {
                    extensionList
                }
            }
        }
    }

    private var extensionsSubtitle: String {
        let kept = ExtensionSelection.keptCount(
            available: foundExtensions,
            removed: selectedExtensionsToRemove
        )

        if kept == foundExtensions.count {
            return "All \(foundExtensions.count) enabled"
        }

        return "\(kept) of \(foundExtensions.count) enabled"
    }

    private var extensionsBinding: Binding<Bool> {
        Binding(
            get: { extensionsExpanded },
            set: { setExtensionsExpanded($0) }
        )
    }

    private func setExtensionsExpanded(_ expanded: Bool) {
        extensionsExpanded = expanded

        guard !expanded else {
            return
        }

        infoAutoCloseToken = UUID()
        expandedExtensionInfo = nil
    }

    private var displayNameCard: some View {
        IPAExpandableCard(
            icon: "textformat",
            title: "Display Name",
            trailingText: cleanDisplayName.isEmpty ? MetadataValidation.cannotBeEmpty : nil,
            trailingColor: .red,
            isExpanded: $displayNameExpanded
        ) {
            IPAFieldBox {
                HStack(spacing: 8) {
                    TextField("App name", text: $displayName)
                        .lineLimit(1)

                    if !displayName.isEmpty {
                        Button {
                            displayName = ""
                            clearStaleExportState()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onChange(of: displayName) { _ in
                clearStaleExportState()
            }

            Text("\(cleanDisplayName.count)/30 characters")
                .font(.caption)
                .foregroundColor(cleanDisplayName.count > 30 ? .red : .secondary)
        }
    }

    private var iconCard: some View {
        IPAExpandableCard(
            icon: "photo",
            title: "App Icon",
            isExpanded: $iconExpanded
        ) {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 22) {
                    IPAIconThumbnail(image: originalIconImage, caption: "Original", size: 72)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(height: 72)

                    IPAIconThumbnail(image: replacementImage, caption: "Replacement", size: 72)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    Button {
                        activeSheet = .iconPhotos
                    } label: {
                        Label("Photos", systemImage: "photo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .ipaidGlassButton(.blue)

                    Button {
                        activeSheet = .iconFiles
                    } label: {
                        Label("Files", systemImage: "folder")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .ipaidGlassButton(.blue)
                }

                if replacementImage != nil {
                    Button("Reset to Original", action: resetIcon)
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                }

                if let iconErrorMessage {
                    IPAInfoBanner(
                        message: iconErrorMessage,
                        color: .red,
                        onDismiss: { self.iconErrorMessage = nil }
                    )
                }

                if let iconHint {
                    Text(iconHint)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func resetIcon() {
        replacementImage = nil
        replacementIconName = ""
        replacementIconFiles = [:]
        iconHint = nil
        iconErrorMessage = nil
        clearStaleExportState()
    }

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            IPASectionHeader(
                title: "Tools",
                isExpanded: toolsExpanded,
                action: toggleTools,
                topPadding: 0
            )
            .padding(.bottom, 4)

            if toolsExpanded {
                IPAToolRow(title: "IPA Info", icon: "info.circle") {
                    activeSheet = .inspector
                }

                IPASubtleDivider()

                IPAToolRow(title: "Version", icon: "number") {
                    activeSheet = .version
                }

                IPASubtleDivider()

                IPAToolRow(title: "URL Scheme", icon: "link") {
                    activeSheet = .urlScheme
                }

                IPASubtleDivider()

                IPAToolRow(title: "Browse Files", icon: "folder") {
                    activeSheet = .browser
                }

                IPASubtleDivider()

                IPAToolRow(title: "Compare IPAs", icon: "arrow.left.arrow.right") {
                    activeSheet = .comparison
                }

                IPASubtleDivider()

                IPAToolRow(title: "Advanced Info.plist", icon: "list.bullet.rectangle") {
                    activeSheet = .plistEditor
                }
            }
        }
        .cardStyle()
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
                            .ipaidMonospacedDigits()
                    }

                    ProgressView(value: exportProgress)
                        .progressViewStyle(LinearProgressViewStyle())

                    Text(exportProgressText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else if !exportStatusMessage.isEmpty {
                IPAInfoBanner(
                    message: exportStatusMessage,
                    color: validationColor,
                    icon: validationIcon
                )
            }

            Button {
                requestExport()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .accentColor(.white)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                    }

                    Text(exportButtonTitle)
                        .font(.headline)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .ipaidProminentButton()
            .disabled(!canExport)
        }
        .cardStyle()
    }

    private var exportButtonTitle: String {
        if isExporting {
            return "Exporting…"
        }

        guard hasPendingChanges else {
            return exportURL == nil ? "No Changes to Export" : "Already Exported"
        }

        return "Export Updated IPA"
    }

    private var outputSection: some View {
        VStack(spacing: 12) {
            if let summary = exportedSummary {
                exportedReviewCard(summary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)

                    Text("Exported")
                        .font(.headline.weight(.bold))

                    Text(fileSizeSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    Image(systemName: "doc.zipper")
                        .foregroundColor(.blue)

                    GeometryReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            TextField("Exported filename", text: $exportFileName)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .lineLimit(1)
                                .ipaidOnSubmit {
                                    renameExportedIPA()
                                }
                                .frame(
                                    width: max(
                                        proxy.size.width,
                                        measuredFileNameWidth(fitting: proxy.size.width)
                                    ),
                                    alignment: .leading
                                )
                        }
                    }
                    .frame(height: 24)

                    Button {
                        exportFileName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 10) {
                    Button(action: discardExport) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")

                            Text("Discard")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 22)
                        .padding(.vertical, 11)
                    }
                    .ipaidGlassButton(.red)

                    Button {
                        activeSheet = .share
                    } label: {
                        Label("Save / Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 22)
                            .padding(.vertical, 11)
                    }
                    .ipaidGlassButton(.blue)
                }

                if !exportSummary.isEmpty {
                    Text(exportSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .cardStyle()
        }
    }

    private func exportedReviewCard(_ summary: IPAModificationSummary) -> some View {
        IPAExpandableCard(
            icon: "checklist",
            title: "Review Changes",
            isExpanded: $exportReviewExpanded
        ) {
            ModificationReviewContent(
                summary: summary,
                originalIcon: originalIconImage,
                replacementIcon: replacementImage
            )
        }
    }

    private var fileSizeSummary: String {
        "Before \(IPAFormatting.fileSize(inputFileSize)) · After \(IPAFormatting.fileSize(outputFileSize))"
    }

    private func measuredFileNameWidth(fitting available: CGFloat) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let width = (exportFileName as NSString).size(withAttributes: [.font: font]).width

        return min(max(width + 16, available), 1600)
    }

    private func discardExport() {
        guard let url = exportURL else {
            return
        }

        session?.discardExport(at: url)

        exportURL = nil
        exportFileName = ""
        exportSummary = ""
        exportedSummary = nil
        exportReviewExpanded = false
        inputFileSize = 0
        outputFileSize = 0
        lastExportSignature = nil
    }

    private var extensionList: some View {
        VStack(alignment: .leading, spacing: 7) {

            bulkExtensionButton

            ForEach(foundExtensions, id: \.self) { path in
                extensionRow(path)
            }
        }
        .padding(9)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bulkExtensionButton: some View {
        let allEnabled = ExtensionSelection.allEnabled(
            available: foundExtensions,
            removed: selectedExtensionsToRemove
        )

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedExtensionsToRemove = ExtensionSelection.bulkSelection(
                    available: foundExtensions,
                    removed: selectedExtensionsToRemove
                )

                clearStaleExportState()
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: allEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(allEnabled ? Color.blue : Color.secondary)

                Text(
                    ExtensionSelection.bulkTitle(
                        available: foundExtensions,
                        removed: selectedExtensionsToRemove
                    )
                )
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

                Spacer()
            }
            .font(.subheadline)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }

    private func extensionRow(_ path: String) -> some View {
        let isSelected =
            selectedExtensionsToRemove.contains(path)

        let isExpanded =
            expandedExtensionInfo == path

        let name =
            IPAExtensionInfo.displayName(forRoot: path)

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
                                ? "circle"
                                : "checkmark.circle.fill"
                        )
                        .foregroundColor(
                            isSelected
                            ? Color.secondary
                            : Color.blue
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
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 30)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Text(
                    IPAExtensionInfo.tip(
                        forName: name,
                        pointIdentifier: extensionPointIdentifier(for: path)
                    )
                )
                .font(.caption)
                .foregroundColor(.secondary)
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

    private func extensionPointIdentifier(for root: String) -> String {
        info?.extensions.first { $0.root == root }?.extensionPointIdentifier ?? ""
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
        activeSheet = nil

        session?.clean()
        session = nil

        ipaURL = nil
        originalFileName = ""

        info = nil
        entries = []
        originalPlist = [:]
        errorMessage = nil

        currentBundleID = ""
        newBundleID = ""

        displayName = ""
        displayNameExpanded = false

        originalURLScheme = ""
        newURLScheme = ""

        newVersion = ""
        newBuild = ""
        versionReferences = []

        originalIconData = nil
        replacementImage = nil
        replacementIconName = ""
        replacementIconFiles = [:]
        iconHint = nil
        iconErrorMessage = nil
        iconExpanded = false

        plistOverrides = InfoPlistOverrides()

        duplicateMode = false

        foundExtensions = []
        selectedExtensionsToRemove = []

        extensionsExpanded = false
        expandedExtensionInfo = nil
        infoTapLocked = false

        copiedBundleID = false

        exportSummary = ""
        exportedSummary = nil
        exportReviewExpanded = false
        editedFiles = [:]

        appVersion = ""
        appBuild = ""

        exportURL = nil
        exportFileName = ""
        inputFileSize = 0
        outputFileSize = 0
        lastExportSignature = nil

        isExporting = false
        exportProgress = 0
        exportProgressText = ""
    }

    private func handleSelectedFile(_ selected: URL) {
        errorMessage = nil
        isImporting = true

        guard let newSession = try? IPASession() else {
            isImporting = false
            errorMessage = "Import failed: Could not create a temporary workspace."
            return
        }

        let fileName = selected.lastPathComponent

        DispatchQueue.global(qos: .userInitiated).async {
            let didAccess = selected.startAccessingSecurityScopedResource()

            defer {
                if didAccess {
                    selected.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let imported = try newSession.importIPA(from: selected)
                let archive = try IPAArchive(url: imported)
                let bundle = archive.info
                let archiveEntries = archive.entries
                let plistDictionary = archive.infoPlist
                let references = IPAVersionReferenceScanner.scan(archive: archive)
                let iconData = bundle.iconPlan.largestExistingSlot
                    .flatMap { try? archive.data(at: $0.path) }

                DispatchQueue.main.async {
                    session?.clean()
                    session = newSession

                    originalFileName = fileName
                    ipaURL = imported
                    info = bundle
                    entries = archiveEntries
                    originalPlist = plistDictionary

                    currentBundleID = bundle.bundleIdentifier
                    newBundleID = bundle.bundleIdentifier

                    displayName = bundle.displayName
                    displayNameExpanded = false

                    originalURLScheme = bundle.urlScheme
                    newURLScheme = bundle.urlScheme

                    appVersion = bundle.marketingVersion
                    appBuild = bundle.buildNumber
                    newVersion = bundle.marketingVersion
                    newBuild = bundle.buildNumber
                    versionReferences = references

                    originalIconData = iconData
                    replacementImage = nil
                    replacementIconName = ""
                    replacementIconFiles = [:]
                    iconHint = nil
                    iconErrorMessage = nil
                    iconExpanded = false

                    foundExtensions = bundle.extensions.map(\.root)
                    selectedExtensionsToRemove = []
                    extensionsExpanded = false
                    expandedExtensionInfo = nil
                    infoTapLocked = false

                    plistOverrides = InfoPlistOverrides()

                    copiedBundleID = false
                    duplicateMode = false

                    exportSummary = ""
                    exportedSummary = nil
                    exportReviewExpanded = false
                    editedFiles = [:]

                    exportURL = nil
                    exportFileName = ""
                    inputFileSize = 0
                    outputFileSize = 0
                    lastExportSignature = nil

                    isExporting = false
                    exportProgress = 0
                    exportProgressText = ""

                    isImporting = false
                }
            } catch {
                newSession.clean()

                DispatchQueue.main.async {
                    UINotificationFeedbackGenerator()
                        .notificationOccurred(.error)

                    isImporting = false
                    errorMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func applyIcon(_ image: UIImage, name: String) {
        guard let plan = info?.iconPlan else {
            return
        }

        guard !plan.slots.isEmpty else {
            iconErrorMessage = "This IPA has no replaceable icon files."
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let preview = IconRenderer.canvasImage(from: image)
            let result = IconRenderer.makeFiles(image: image, plan: plan)

            DispatchQueue.main.async {
                guard !result.files.isEmpty else {
                    iconErrorMessage = result.problems.first ?? "Could not prepare the icon."
                    return
                }

                replacementImage = preview
                replacementIconName = name
                replacementIconFiles = result.files
                iconHint = result.problems.first
                iconErrorMessage = nil
                clearStaleExportState()
            }
        }
    }

    private func loadIconFile(_ url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
            iconErrorMessage = "The selected image could not be read."
            return
        }

        applyIcon(image, name: url.lastPathComponent)
    }

    private func applyPreset(_ plan: ExportPresetPlan) {
        guard info != nil else {
            return
        }

        let updated = plan.modifications

        newBundleID = updated.bundleIdentifier
        displayName = updated.displayName
        newURLScheme = updated.urlScheme
        newVersion = updated.marketingVersion
        newBuild = updated.buildNumber
        selectedExtensionsToRemove = updated.removedExtensions
        duplicateMode = false

        clearStaleExportState()
    }

    private func requestExport() {
        guard let info else {
            return
        }

        let problems = currentModifications.problems(comparedTo: info)

        guard problems.isEmpty else {
            errorMessage = problems[0]
            return
        }

        guard currentModifications.hasChanges(from: info) else {
            return
        }

        errorMessage = nil

        if skipReview {
            performExport()
        } else {
            activeSheet = .modificationPreview
        }
    }

    private func performExport() {
        guard let info, let session, let sourceURL = ipaURL else {
            return
        }

        let modifications = currentModifications
        let problems = modifications.problems(comparedTo: info)

        guard problems.isEmpty else {
            errorMessage = problems[0]
            activeSheet = nil
            return
        }

        guard modifications.hasChanges(from: info) else {
            activeSheet = nil
            return
        }

        let output: URL

        do {
            output = try session.outputURL(for: exportBaseName)
        } catch {
            errorMessage = "Could not prepare the export folder."
            activeSheet = nil
            return
        }

        let signature = modifications.fingerprint
        let summary = IPAModificationSummary(
            info: info,
            entries: entries,
            modifications: modifications
        )

        isExporting = true
        exportProgress = 0
        exportProgressText = "Preparing archive…"
        exportURL = nil
        exportSummary = ""
        errorMessage = nil
        inputFileSize = IPAFormatting.fileSize(of: sourceURL)
        outputFileSize = 0

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var lastPercent = -1

                let result = try IPAExporter.export(
                    IPAExportRequest(
                        sourceURL: sourceURL,
                        outputURL: output,
                        modifications: modifications
                    ),
                    progress: { progress, text in
                        let percent = Int(progress * 100)

                        guard percent != lastPercent else {
                            return
                        }

                        lastPercent = percent

                        DispatchQueue.main.async {
                            exportProgress = progress
                            exportProgressText = text
                        }
                    }
                )

                DispatchQueue.main.async {
                    exportURL = result.outputURL
                    exportFileName = result.outputURL.lastPathComponent
                    inputFileSize = IPAFormatting.fileSize(of: sourceURL)
                    outputFileSize = result.fileSize
                    lastExportSignature = signature
                    exportSummary = exportSummaryText(summary)
                    exportedSummary = result.summary
                    exportReviewExpanded = false

                    extensionsExpanded = false
                    expandedExtensionInfo = nil

                    exportProgress = 1
                    exportProgressText = "Export complete."
                    isExporting = false

                    UINotificationFeedbackGenerator()
                        .notificationOccurred(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    isExporting = false
                    exportProgress = 0
                    exportProgressText = ""
                    exportSummary = ""
                    errorMessage = "Export failed: \(error.localizedDescription)"

                    UINotificationFeedbackGenerator()
                        .notificationOccurred(.error)
                }
            }
        }
    }

    private var exportBaseName: String {
        IPAFormatting.exportFileName(
            originalFileName: originalFileName,
            suffix: exportSuffix
        )
    }

    private func exportSummaryText(_ summary: IPAModificationSummary) -> String {
        let labels = summary.changes.map(\.label)

        guard !labels.isEmpty else {
            return ""
        }

        return "Applied: " + labels.joined(separator: ", ")
    }


    private func renameExportedIPA() {
        guard let currentURL = exportURL else { return }
        var name = exportFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = URL(fileURLWithPath: name).lastPathComponent
        if !name.lowercased().hasSuffix(".ipa") { name += ".ipa" }
        guard name.count > 4 else { return }

        let destination = currentURL.deletingLastPathComponent().appendingPathComponent(name)
        if destination == currentURL { return }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: currentURL, to: destination)
            exportURL = destination
            exportFileName = destination.lastPathComponent
            outputFileSize = IPAFormatting.fileSize(of: destination)
            errorMessage = nil
        } catch {
            errorMessage = "Could not rename the exported IPA: \(error.localizedDescription)"
        }
    }


    private func clearStaleExportState() {
        exportSummary = ""
    }

}


private enum ActiveSheet: String, Identifiable {
    case picker
    case share
    case inspector
    case version
    case urlScheme
    case browser
    case plistEditor
    case comparison
    case presets
    case modificationPreview
    case iconPhotos
    case iconFiles

    var id: String {
        rawValue
    }
}
