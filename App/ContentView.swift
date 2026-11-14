import SwiftUI
import Foundation
import UniformTypeIdentifiers
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
    @State private var validationMessage = ""

    @State private var appVersion = ""
    @State private var appBuild = ""

    @State private var rewrittenExtensions = 0

    @State private var status = "Select an IPA to begin."
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

    @State private var plistOverrides = InfoPlistOverrides()

    @State private var errorMessage: String?

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

    private var currentSettingsSignature: String {
        let extensions = selectedExtensionsToRemove.sorted().joined(separator: "\u{1F}")
        let iconFiles = replacementIconFiles
            .map { "\($0.key):\($0.value.count)" }
            .sorted()
            .joined(separator: "\u{1F}")
        let overrideKeys = plistOverrides.values.keys.sorted().joined(separator: ",")
        let overrideValues = plistOverrides.values.keys
            .sorted()
            .compactMap { plistOverrides.values[$0]?.displayText }
            .joined(separator: "\u{1F}")
        let removedKeys = plistOverrides.removedKeys.sorted().joined(separator: ",")

        return [
            cleanNewBundleID,
            cleanDisplayName,
            cleanURLScheme,
            cleanVersion,
            cleanBuild,
            extensions,
            replacementIconName,
            iconFiles,
            overrideKeys,
            overrideValues,
            removedKeys
        ].joined(separator: "\u{1E}")
    }

    private var hasPendingChanges: Bool {
        guard let info, currentModifications.hasChanges(from: info) else {
            return false
        }

        if let lastExportSignature, exportURL != nil {
            return currentSettingsSignature != lastExportSignature
        }

        return true
    }

    private var canExport: Bool {
        info != nil &&
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
            IPATemporaryStore.pruneSessions()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !originalFileName.isEmpty {
                    fileInfoSection
                }

                if let errorMessage {
                    IPAInfoBanner(message: errorMessage, color: .red)
                }

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
        .clipShape(RoundedRectangle(cornerRadius: 11))
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
                    if !newVersion.isEmpty {
                        Text("v\(newVersion)")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text("Build \(newBuild.isEmpty ? "Unknown" : newBuild)")
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
                        validationMessage = MetadataValidation.bundleIdentifier(newBundleID)
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
                        validationMessage = MetadataValidation.bundleIdentifier(paste)
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

                validationMessage = MetadataValidation.bundleIdentifier(value)
                clearStaleExportState()
            }

            Button {
                duplicateMode.toggle()

                if duplicateMode {
                    newBundleID = currentBundleID + ".ipaid"
                } else {
                    newBundleID = currentBundleID
                }

                validationMessage = MetadataValidation.bundleIdentifier(newBundleID)
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
                extensionRemovalSection
                    .cardStyle()
            }
        }
    }

    private var displayNameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayNameExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "textformat")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Display Name")
                            .font(.headline.weight(.bold))
                        Text(cleanDisplayName.isEmpty ? "No name" : cleanDisplayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Image(systemName: displayNameExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            if displayNameExpanded {
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
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: displayName) { _ in
                    clearStaleExportState()
                }

                Text("\(cleanDisplayName.count)/30 characters")
                    .font(.caption)
                    .foregroundColor(cleanDisplayName.count > 30 ? .red : .secondary)
            }
        }
        .cardStyle()
    }

    private var urlSchemeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    urlSchemeExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("URL Scheme")
                            .font(.headline.weight(.bold))
                        Text(cleanURLScheme.isEmpty ? "None" : cleanURLScheme)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Image(systemName: urlSchemeExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            if urlSchemeExpanded {
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
                .padding(.horizontal, 13)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: newURLScheme) { _ in
                    clearStaleExportState()
                }

            }
        }
        .cardStyle()
    }

    private var versionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    versionExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Version")
                            .font(.headline.weight(.bold))

                        Text(versionSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: versionExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            if versionExpanded {
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
        .cardStyle()
    }

    private var versionSubtitle: String {
        let version = cleanVersion.isEmpty ? "Unknown" : cleanVersion
        let build = cleanBuild.isEmpty ? "Unknown" : cleanBuild
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
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "photo", title: "App Icon")

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
                    Button("Reset") {
                        replacementImage = nil
                        replacementIconName = ""
                        replacementIconFiles = [:]
                        iconHint = nil
                        clearStaleExportState()
                    }
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
        .cardStyle()
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: validationIcon)
                .foregroundColor(validationColor)

            Text(currentChangeMessage)
                .font(.subheadline)
                .foregroundColor(validationColor)

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

                    Text(
                        isExporting
                        ? "Exporting…"
                        : (exportURL != nil && !hasPendingChanges
                           ? "Already Exported"
                           : "Export Updated IPA")
                    )
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

    private func outputSection(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "checkmark.circle.fill", title: "Exported IPA")

            Text("Export complete.")
                .font(.subheadline.weight(.semibold))

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
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                activeSheet = .share
            } label: {
                Label("Save / Share IPA", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .ipaidBorderedButton()

            HStack(spacing: 18) {
                Text("Before: \(formattedFileSize(inputFileSize))")
                Text("After: \(formattedFileSize(outputFileSize))")
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)

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
                            selectedExtensionsToRemove.isEmpty
                            ? "All \(foundExtensions.count) enabled"
                            : "\(foundExtensions.count - selectedExtensionsToRemove.count) of \(foundExtensions.count) enabled"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                .foregroundColor(
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
                    extensionTip(
                        for: extensionName(from: path)
                    )
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
        validationMessage = ""

        appVersion = ""
        appBuild = ""

        rewrittenExtensions = 0

        exportURL = nil
        exportFileName = ""
        inputFileSize = 0
        outputFileSize = 0
        lastExportSignature = nil

        isExporting = false
        exportProgress = 0
        exportProgressText = ""

        status = "Select an IPA to begin."
    }


    private func handleSelectedFile(_ selected: URL) {
        errorMessage = nil

        let didAccess = selected.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                selected.stopAccessingSecurityScopedResource()
            }
        }

        guard let newSession = try? IPASession() else {
            errorMessage = "Import failed: Could not create a temporary workspace."
            status = "Import failed."
            return
        }

        do {
            let imported = try newSession.importIPA(from: selected)
            let archive = try IPAArchive(url: imported)
            let bundle = archive.info

            session?.clean()
            session = newSession

            originalFileName = selected.lastPathComponent
            ipaURL = imported
            info = bundle
            entries = archive.entries
            originalPlist = archive.infoPlist

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
            versionReferences = IPAVersionReferenceScanner.scan(archive: archive)

            originalIconData = largestIconData(in: archive, plan: bundle.iconPlan)
            replacementImage = nil
            replacementIconName = ""
            replacementIconFiles = [:]
            iconHint = nil

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
            validationMessage = MetadataValidation.bundleIdentifier(bundle.bundleIdentifier)

            exportURL = nil
            exportFileName = ""
            inputFileSize = 0
            outputFileSize = 0
            lastExportSignature = nil

            rewrittenExtensions = 0

            isExporting = false
            exportProgress = 0
            exportProgressText = ""

            status = ""
        } catch {
            newSession.clean()

            UINotificationFeedbackGenerator()
                .notificationOccurred(.error)

            errorMessage = "Import failed: \(error.localizedDescription)"
            status = "Import failed."
        }
    }

    private func largestIconData(in archive: IPAArchive, plan: IPAIconPlan) -> Data? {
        guard let slot = plan.largestExistingSlot else {
            return nil
        }

        return try? archive.data(at: slot.path)
    }

    private func applyIcon(_ image: UIImage, name: String) {
        guard let info else {
            return
        }

        let result = IconRenderer.makeFiles(image: image, plan: info.iconPlan)

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

        validationMessage = MetadataValidation.bundleIdentifier(modifications.bundleIdentifier)
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

        let signature = currentSettingsSignature
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
        inputFileSize = fileSize(of: sourceURL)
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
                    inputFileSize = fileSize(of: sourceURL)
                    outputFileSize = result.fileSize
                    lastExportSignature = signature
                    exportSummary = exportSummaryText(summary)

                    extensionsExpanded = false
                    expandedExtensionInfo = nil

                    exportProgress = 1
                    exportProgressText = "Export complete."
                    isExporting = false
                    status = "Export complete. Original file was not replaced."

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
                    status = "Export failed."

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


    private func updateExportProgress(
        progress: Double,
        text: String
    ) {
        DispatchQueue.main.async {
            exportProgress =
                min(max(progress, 0), 1)

            exportProgressText = text
        }
    }


    private func fileSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize else { return 0 }
        return Int64(size)
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
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
            outputFileSize = fileSize(of: destination)
            status = "Export complete. Original file was not replaced."
        } catch {
            status = "Could not rename exported IPA: \(error.localizedDescription)"
        }
    }


    private func clearStaleExportState() {

        guard
            exportURL != nil ||
            rewrittenExtensions != 0 ||
            status.hasPrefix("Export")
        else {
            return
        }

        // Keep the existing exported IPA visible. It remains a valid previous
        // export, but a new export is required because the edited settings
        // no longer match that file.
        rewrittenExtensions = 0
        exportSummary = ""
        copiedFilename = false

        status =
            "Changes updated. Export again to create a new IPA."
    }

    private func middleTruncated(
        _ text: String,
        limit: Int
    ) -> String {

        guard text.count > limit,
              limit > 8 else {
            return text
        }

        let keep =
            max(
                4,
                (limit - 1) / 2
            )

        let start =
            text.prefix(keep)

        let end =
            text.suffix(keep)

        return "\(start)…\(end)"
    }

    private func extensionName(
        from path: String
    ) -> String {

        let parts =
            path
                .split(separator: "/")
                .map(String.init)

        let rawName: String

        if let appExtension =
            parts.first(
                where: {
                    $0.hasSuffix(".appex")
                }
            ) {

            rawName =
                appExtension
                    .replacingOccurrences(
                        of: ".appex",
                        with: ""
                    )

        } else {

            rawName =
                URL(fileURLWithPath: path)
                    .deletingPathExtension()
                    .lastPathComponent
        }

        return humanReadableExtensionName(
            rawName
        )
    }

    private func humanReadableExtensionName(
        _ raw: String
    ) -> String {

        var name = raw

        if name.hasSuffix("Extension") {
            name.removeLast(
                "Extension".count
            )
        }

        name =
            name.replacingOccurrences(
                of: "_",
                with: " "
            )

        name =
            name.replacingOccurrences(
                of: "-",
                with: " "
            )

        var result = ""
        var previousWasLowercaseOrNumber = false

        for character in name {

            let scalar =
                String(character)

            let isUppercase =
                scalar.rangeOfCharacter(
                    from: .uppercaseLetters
                ) != nil

            let isNumber =
                scalar.rangeOfCharacter(
                    from: .decimalDigits
                ) != nil

            if isUppercase &&
                previousWasLowercaseOrNumber &&
                !result.hasSuffix(" ") {

                result.append(" ")
            }

            result.append(character)

            previousWasLowercaseOrNumber =
                scalar.rangeOfCharacter(
                    from: .lowercaseLetters
                ) != nil ||
                isNumber
        }

        let cleaned =
            result
                .replacingOccurrences(
                    of: "  ",
                    with: " "
                )
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        return cleaned.isEmpty
            ? raw
            : cleaned
    }

    private func extensionTip(
        for name: String
    ) -> String {

        let lower =
            name.lowercased()

        if lower.contains("widget") {
            return "Adds Home Screen or Lock Screen widget support. Removing it disables that widget."
        }

        if lower.contains("intent") ||
            lower.contains("siri") {

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


}


private struct InfoView: View {
    let currentVersion: String
    @Binding var appearanceMode: String

    @State private var isCheckingForUpdate = false
    @State private var updateAlert: UpdateAlert?

    private let githubURL = URL(string: "https://github.com/shplash/IPAID")!
    private let reportIssueURL = URL(string: "https://tally.so/r/gDE8pP")!
    private let featureRequestURL = URL(string: "https://tally.so/r/9q8Ag5")!
    private let supportURL = URL(string: "https://ko-fi.com/shplash")!

    var body: some View {
        infoContentCard
            .alert(item: $updateAlert) { alert in
                if let url = alert.url {
                    return Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        primaryButton: .default(Text("View Update")) {
                            UIApplication.shared.open(url)
                        },
                        secondaryButton: .cancel()
                    )
                }

                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    private var infoContentCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Appearance", icon: "circle.lefthalf.filled")

            appearanceControl
                .padding(.top, 15)
                .padding(.bottom, 4)

            subtleDivider
                .padding(.top, 30)

            sectionHeader("Links", icon: "link")
                .padding(.top, 28)
                .padding(.bottom, 4)

            infoRow(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right") {
                UIApplication.shared.open(githubURL)
            }

            subtleDivider

            infoRow(title: "Check for Updates", icon: "arrow.clockwise", trailingProgress: isCheckingForUpdate) {
                checkForUpdates()
            }
            .disabled(isCheckingForUpdate)

            subtleDivider
                .padding(.top, 6)

            infoRow(title: "Support Me", icon: "heart") {
                UIApplication.shared.open(supportURL)
            }
            .foregroundColor(.primary)

            subtleDivider
                .padding(.top, 6)

            sectionHeader("Feedback", icon: "bubble.left.and.bubble.right")
                .padding(.top, 30)
                .padding(.bottom, 4)

            infoRow(title: "Report a Bug", icon: "ladybug") {
                UIApplication.shared.open(reportIssueURL)
            }

            subtleDivider

            infoRow(title: "Request a Feature", icon: "lightbulb") {
                UIApplication.shared.open(featureRequestURL)
            }

            subtleDivider
                .padding(.top, 6)

            sectionHeader("Credits", icon: "person.crop.circle")
                .padding(.top, 30)
                .padding(.bottom, 2)

            Text("Developed by shplash")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 12)

            Text("Built with SwiftUI and ZIPFoundation")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)

            subtleDivider
                .padding(.top, 24)

        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var appearanceControl: some View {
        HStack(spacing: 0) {
            appearanceButton("System", value: "system")
            appearanceButton("Light", value: "light")
            appearanceButton("Dark", value: "dark")
        }
        .padding(4)
        .background(Color.primary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private func appearanceButton(_ title: String, value: String) -> some View {
        Button {
            guard appearanceMode != value else { return }
            appearanceMode = value
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(appearanceMode == value ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            appearanceMode == value
                                ? Color.primary.opacity(0.11)
                                : Color.clear
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var subtleDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.055))
            .frame(height: 1)
            .padding(.leading, 44)
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 26)

            Text(title)
                .font(.headline.weight(.bold))
        }
    }

    private func infoRow(
        title: String,
        icon: String,
        trailingProgress: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor((title == "GitHub" || title == "Check for Updates" || title == "Report a Bug" || title == "Request a Feature" || title == "Support Me") ? Color.primary : Color.blue)
                    .frame(width: 26)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                if trailingProgress {
                    ProgressView()
                        .ipaidSmallControl()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.secondary.opacity(0.55))
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 17)
        }
        .buttonStyle(.plain)
    }

    private func checkForUpdates() {
        guard !isCheckingForUpdate else { return }

        isCheckingForUpdate = true

        var request = URLRequest(
            url: URL(string: "https://api.github.com/repos/shplash/IPAID/releases/latest")!
        )
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("IPAID", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data,
                  let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode,
                  let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                DispatchQueue.main.async {
                    isCheckingForUpdate = false
                    updateAlert = UpdateAlert(
                        title: "Couldn't Check for Updates",
                        message: "Please check your internet connection and try again."
                    )
                }
                return
            }

            let latestVersion = release.tagName
                .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            DispatchQueue.main.async {
                isCheckingForUpdate = false

                if compareVersions(latestVersion, currentVersion) > 0,
                   let url = URL(string: release.htmlURL) {
                    updateAlert = UpdateAlert(
                        title: "Update Available",
                        message: "IPAID \(latestVersion) is available. You're running \(currentVersion).",
                        url: url
                    )
                } else {
                    updateAlert = UpdateAlert(
                        title: "You're Up to Date",
                        message: "IPAID \(currentVersion) is the latest release."
                    )
                }
            }
        }
        .resume()
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let left = versionNumbers(lhs)
        let right = versionNumbers(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0

            if l > r { return 1 }
            if l < r { return -1 }
        }

        return 0
    }

    private func versionNumbers(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { component in
                Int(component.prefix { $0.isNumber }) ?? 0
            }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

private struct UpdateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let url: URL?

    init(title: String, message: String, url: URL? = nil) {
        self.title = title
        self.message = message
        self.url = url
    }
}

struct ActivityView:
    UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {

        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

struct DocumentPicker:
    UIViewControllerRepresentable {

    let onPick: (URL) -> Void
    let onCancel: (() -> Void)?

    init(
        onPick: @escaping (URL) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPick: onPick,
            onCancel: onCancel
        )
    }

    func makeUIViewController(
        context: Context
    ) -> UIDocumentPickerViewController {

        let picker =
            UIDocumentPickerViewController(
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

    final class Coordinator:
        NSObject,
        UIDocumentPickerDelegate {

        let onPick: (URL) -> Void
        let onCancel: (() -> Void)?

        init(
            onPick: @escaping (URL) -> Void,
            onCancel: (() -> Void)?
        ) {
            self.onPick = onPick
            self.onCancel = onCancel
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

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            onCancel?()
        }
    }
}

struct SimpleError:
    LocalizedError {

    let message: String

    init(
        _ message: String
    ) {
        self.message = message
    }

    var errorDescription: String? {
        message
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
