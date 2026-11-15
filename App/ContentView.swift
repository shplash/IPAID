import SwiftUI
import Foundation
import ZIPFoundation
import UIKit

struct ContentView: View {

    @State private var activeSheet: ActiveSheet?
    @State private var showInfo = false
    @AppStorage("ipaidAppearance") private var appearanceMode = "system"

    @State private var ipaURL: URL?
    @State private var originalFileName = ""

    @State private var currentBundleID = ""
    @State private var newBundleID = ""

    @State private var displayName = ""
    @State private var originalDisplayName = ""
    @State private var displayNameExpanded = false

    @State private var originalURLScheme = ""
    @State private var newURLScheme = ""
    @State private var urlSchemeExpanded = false

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

    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var exportURL: URL?
    @State private var exportFileName = ""
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
    @State private var versionExpanded = false
    @State private var versionReferences: [IPAVersionReference] = []

    @State private var originalIconData: Data?
    @State private var replacementImage: UIImage?
    @State private var replacementIconName = ""
    @State private var replacementIconFiles: [String: Data] = [:]
    @State private var iconHint: String?
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

    private var cleanOriginalDisplayName: String {
        originalDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayedOriginalFileName: String {
        IPAFormatting.middleTruncated(originalFileName, limit: 34)
    }

    private var bundleIDChanged: Bool {
        !cleanCurrentBundleID.isEmpty &&
        cleanNewBundleID != cleanCurrentBundleID
    }

    private var displayNameChanged: Bool {
        cleanDisplayName != cleanOriginalDisplayName
    }

    private var cleanURLScheme: String {
        newURLScheme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanVersion: String {
        newVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanBuild: String {
        newBuild.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var versionChanged: Bool {
        cleanVersion != appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var buildChanged: Bool {
        cleanBuild != appBuild.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private var urlSchemeChanged: Bool {
        cleanURLScheme != originalURLScheme.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private var currentChangeMessage: String {
        guard let info else {
            return ""
        }

        if let problem = currentModifications.problems(comparedTo: info).first {
            return problem
        }

        if !hasPendingChanges {
            if exportURL != nil {
                return "Export complete — no changes detected."
            }
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

                case .browser:
                    if let ipaURL {
                        FileBrowserView(
                            ipaURL: ipaURL,
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
                if !originalFileName.isEmpty {
                    fileInfoSection
                }

                if isImporting {
                    IPALoadingRow(text: "Reading IPA…")
                }

                if let errorMessage {
                    IPAInfoBanner(message: errorMessage, color: .red)
                }

                if currentBundleID.isEmpty {
                    emptyStateSection
                } else {
                    editorSection
                }

                if exportURL != nil {
                    outputSection
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
                InfoView(currentVersion: currentAppVersion, appearanceMode: $appearanceMode)
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("IPAID")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("IPA Bundle ID Editor")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.28)) {
                        showInfo.toggle()
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("v\(currentAppVersion)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            urlSchemeCard

            versionCard

            iconCard

            extensionCard

            toolsCard

            if exportURL == nil || hasPendingChanges || isExporting {
                validationCard
            }

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
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if !appVersion.isEmpty {
                        Text("v\(appVersion)")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text("Build \(appBuild.isEmpty ? "Unknown" : appBuild)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .ipaidTextSelection()

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
            .foregroundColor(.secondary)

            Divider()

            Text("New Bundle ID")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                TextField(
                    "com.example.app",
                    text: $newBundleID
                )
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)

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

                Button {
                    if let paste = UIPasteboard.general.string {
                        newBundleID = paste
                        clearStaleExportState()
                    }
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .foregroundColor(.secondary)
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

                clearStaleExportState()
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
        .cardStyle()
    }

    private var extensionCard: some View {
        Group {
            if !foundExtensions.isEmpty {
                IPAExpandableCard(
                    icon: selectedExtensionsToRemove.isEmpty
                        ? "puzzlepiece.extension"
                        : "checkmark.circle.fill",
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
        if selectedExtensionsToRemove.isEmpty {
            return "All \(foundExtensions.count) enabled"
        }

        return "\(foundExtensions.count - selectedExtensionsToRemove.count) of \(foundExtensions.count) enabled"
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
            subtitle: cleanDisplayName.isEmpty ? "No name" : cleanDisplayName,
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

                    Button {
                        if let paste = UIPasteboard.general.string {
                            displayName = paste
                            clearStaleExportState()
                        }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
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

    private var urlSchemeCard: some View {
        IPAExpandableCard(
            icon: "link",
            title: "URL Scheme",
            subtitle: cleanURLScheme.isEmpty ? "None" : cleanURLScheme,
            isExpanded: $urlSchemeExpanded
        ) {
            IPAFieldBox {
                HStack(spacing: 8) {
                    TextField("myapp", text: $newURLScheme)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)

                    if !newURLScheme.isEmpty {
                        Button {
                            newURLScheme = ""
                            clearStaleExportState()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onChange(of: newURLScheme) { _ in
                clearStaleExportState()
            }
        }
    }

    private var versionCard: some View {
        IPAExpandableCard(
            icon: "number",
            title: "Version",
            subtitle: versionSubtitle,
            isExpanded: $versionExpanded
        ) {
            versionField(
                title: "Marketing Version",
                placeholder: "1.0",
                text: $newVersion,
                original: appVersion,
                error: versionChanged ? MetadataValidation.marketingVersion(cleanVersion) : ""
            )

            versionField(
                title: "Build Number",
                placeholder: "1",
                text: $newBuild,
                original: appBuild,
                error: buildChanged ? MetadataValidation.buildNumber(cleanBuild) : ""
            )

            if versionChanged, !versionReferences.isEmpty {
                Text(versionReferenceText)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Metadata only. This does not change the app's actual version.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var versionSubtitle: String {
        let version = cleanVersion.isEmpty
            ? (appVersion.isEmpty ? "Unknown" : appVersion)
            : cleanVersion
        let build = cleanBuild.isEmpty
            ? (appBuild.isEmpty ? "Unknown" : appBuild)
            : cleanBuild

        return "\(version) (\(build))"
    }

    private var versionReferenceText: String {
        let name = versionReferences[0].path
            .split(separator: "/")
            .last
            .map(String.init) ?? versionReferences[0].path

        if versionReferences.count == 1 {
            return "The old version also appears in \(name). Only Info.plist is changed."
        }

        return "The old version also appears in \(versionReferences.count) bundled files, such as \(name). Only Info.plist is changed."
    }

    private func versionField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        original: String,
        error: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if !original.isEmpty {
                    Text("Original \(original)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            IPAFieldBox {
                TextField(placeholder, text: text)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .onChange(of: text.wrappedValue) { _ in
                clearStaleExportState()
            }

            if !error.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }

    private var iconCard: some View {
        IPAExpandableCard(
            icon: "photo",
            title: "App Icon",
            subtitle: iconSubtitle,
            isExpanded: $iconExpanded
        ) {
            HStack(spacing: 14) {
                IPAIconThumbnail(image: originalIconImage, caption: "Original", size: 62)

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                IPAIconThumbnail(image: replacementImage, caption: "Replacement", size: 62)

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    activeSheet = .iconPhotos
                } label: {
                    Label("Photos", systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                }
                .ipaidBorderedButton()

                Button {
                    activeSheet = .iconFiles
                } label: {
                    Label("Files", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                }
                .ipaidBorderedButton()

                if replacementImage != nil {
                    Button("Reset", action: resetIcon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }

            if let iconHint {
                Text(iconHint)
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !iconSlotText.isEmpty {
                Text(iconSlotText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var iconSubtitle: String {
        guard replacementImage != nil else {
            return "Original"
        }

        return replacementIconName.isEmpty ? "Replacement ready" : replacementIconName
    }

    private func resetIcon() {
        replacementImage = nil
        replacementIconName = ""
        replacementIconFiles = [:]
        iconHint = nil
        clearStaleExportState()
    }

    private var iconSlotText: String {
        guard let info else {
            return ""
        }

        let count = info.iconPlan.slots.count

        if count == 0 {
            return "No replaceable icon files found."
        }

        return replacementImage == nil
            ? "\(count) icon sizes available"
            : "\(replacementIconFiles.count) icons ready"
    }

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(icon: "wrench.and.screwdriver", title: "Tools")

            IPASubtleDivider()
                .padding(.top, 12)

            IPAToolRow(title: "IPA Info", icon: "info.circle") {
                activeSheet = .inspector
            }

            IPASubtleDivider()

            IPAToolRow(title: "Browse Files", icon: "folder") {
                activeSheet = .browser
            }

            IPASubtleDivider()

            IPAToolRow(title: "Advanced Info.plist", icon: "list.bullet.rectangle") {
                activeSheet = .plistEditor
            }

            IPASubtleDivider()

            IPAToolRow(title: "Compare IPAs", icon: "arrow.left.arrow.right") {
                activeSheet = .comparison
            }

            IPASubtleDivider()

            IPAToolRow(title: "Export Presets", icon: "slider.horizontal.3") {
                activeSheet = .presets
            }
        }
        .cardStyle()
    }

    private var validationCard: some View {
        IPAInfoBanner(
            message: currentChangeMessage,
            color: validationColor,
            icon: validationIcon
        )
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

            if !exportSummary.isEmpty {
                Text(exportSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "checkmark.circle.fill", title: "Exported IPA")

            Text(
                hasPendingChanges
                    ? "Previous export. Export again to include your latest changes."
                    : "Export complete."
            )
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Image(systemName: "doc.zipper")
                    .foregroundColor(.blue)

                TextField("Exported filename", text: $exportFileName)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .lineLimit(1)
                    .ipaidOnSubmit {
                        renameExportedIPA()
                    }

                Button {
                    UIPasteboard.general.string = exportFileName
                    copiedFilename = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        copiedFilename = false
                    }
                } label: {
                    Image(systemName: copiedFilename ? "checkmark" : "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                activeSheet = .share
            } label: {
                Label("Save / Share IPA", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .ipaidBorderedButton()

            HStack(spacing: 18) {
                Text("Before: \(IPAFormatting.fileSize(inputFileSize))")
                Text("After: \(IPAFormatting.fileSize(outputFileSize))")
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private func sectionTitle(
        icon: String,
        title: String
    ) -> some View {
        IPASectionTitle(icon: icon, title: title)
    }

    private var extensionList: some View {
        VStack(alignment: .leading, spacing: 7) {

            ForEach(foundExtensions, id: \.self) { path in
                extensionRow(path)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedExtensionsToRemove = []

                    clearStaleExportState()
                }
            } label: {
                HStack {
                    Image(
                        systemName:
                            selectedExtensionsToRemove.isEmpty
                            ? "checkmark.circle.fill"
                            : "circle"
                    )

                    Text(
                        selectedExtensionsToRemove.isEmpty
                        ? "All Enabled"
                        : "Enable All"
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    IPAExtensionInfo.tip(forName: name)
                )
                .font(.caption2)
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
        originalDisplayName = ""
        displayNameExpanded = false

        originalURLScheme = ""
        newURLScheme = ""
        urlSchemeExpanded = false

        newVersion = ""
        newBuild = ""
        versionExpanded = false
        versionReferences = []

        originalIconData = nil
        replacementImage = nil
        replacementIconName = ""
        replacementIconFiles = [:]
        iconHint = nil
        iconExpanded = false

        plistOverrides = InfoPlistOverrides()

        duplicateMode = false

        foundExtensions = []
        selectedExtensionsToRemove = []

        extensionsExpanded = false
        expandedExtensionInfo = nil
        infoTapLocked = false

        copiedFilename = false
        copiedBundleID = false

        exportSummary = ""

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
                    originalDisplayName = bundle.displayName
                    displayNameExpanded = false

                    originalURLScheme = bundle.urlScheme
                    newURLScheme = bundle.urlScheme
                    urlSchemeExpanded = false

                    appVersion = bundle.marketingVersion
                    appBuild = bundle.buildNumber
                    newVersion = bundle.marketingVersion
                    newBuild = bundle.buildNumber
                    versionExpanded = false
                    versionReferences = references

                    originalIconData = iconData
                    replacementImage = nil
                    replacementIconName = ""
                    replacementIconFiles = [:]
                    iconHint = nil
                    iconExpanded = false

                    foundExtensions = bundle.extensions.map(\.root)
                    selectedExtensionsToRemove = []
                    extensionsExpanded = false
                    expandedExtensionInfo = nil
                    infoTapLocked = false

                    plistOverrides = InfoPlistOverrides()

                    copiedFilename = false
                    copiedBundleID = false
                    duplicateMode = false

                    exportSummary = ""

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
            errorMessage = "No replaceable icon files were found in this IPA."
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let result = IconRenderer.makeFiles(image: image, plan: plan)

            DispatchQueue.main.async {
                guard !result.files.isEmpty else {
                    errorMessage = result.problems.first ?? "Could not prepare the icon."
                    return
                }

                replacementImage = image
                replacementIconName = name
                replacementIconFiles = result.files
                iconHint = result.problems.first
                errorMessage = nil
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
            errorMessage = "The selected image could not be read."
            return
        }

        applyIcon(image, name: url.lastPathComponent)
    }

    private func applyPreset(_ preset: ExportPreset) {
        guard let info else {
            return
        }

        var modifications = currentModifications
        preset.apply(to: &modifications, availableExtensions: info.extensions)

        newBundleID = modifications.bundleIdentifier
        displayName = modifications.displayName
        newURLScheme = modifications.urlScheme
        newVersion = modifications.marketingVersion
        newBuild = modifications.buildNumber
        selectedExtensionsToRemove = modifications.removedExtensions
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
        activeSheet = .modificationPreview
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
        let name = originalFileName.isEmpty
            ? "IPA"
            : URL(fileURLWithPath: originalFileName).deletingPathExtension().lastPathComponent

        return "\(name)-ipaid.ipa"
    }

    private func exportSummaryText(_ summary: IPAModificationSummary) -> String {
        let labels = summary.changes.map(\.label)

        guard !labels.isEmpty else {
            return ""
        }

        return "Applied: " + labels.joined(separator: " • ")
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
        copiedFilename = false
    }

}


private enum ActiveSheet: String, Identifiable {
    case picker
    case share
    case inspector
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
