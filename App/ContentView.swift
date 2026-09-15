import SwiftUI
import Foundation
import UniformTypeIdentifiers
import ZIPFoundation
import UIKit

struct ContentView: View {

    @State private var showPicker = false
    @State private var showShareSheet = false
    @State private var showInfo = false
    @AppStorage("ipaidAppearance") private var appearanceMode = "system"

    @State private var ipaURL: URL?
    @State private var originalFileName = ""
    @State private var appInfoPlistPath: String?

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

    private var urlSchemeChanged: Bool {
        cleanURLScheme != originalURLScheme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var extensionRemovalChanged: Bool {
        !selectedExtensionsToRemove.isEmpty
    }

    private var currentSettingsSignature: String {
        let extensions = selectedExtensionsToRemove.sorted().joined(separator: "\u{1F}")
        return [
            cleanNewBundleID,
            cleanDisplayName,
            cleanURLScheme,
            extensions
        ].joined(separator: "\u{1E}")
    }

    private var hasPendingChanges: Bool {
        if let lastExportSignature, exportURL != nil {
            return currentSettingsSignature != lastExportSignature
        }

        return bundleIDChanged ||
        displayNameChanged ||
        urlSchemeChanged ||
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

        if !validateURLScheme(cleanURLScheme).isEmpty {
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

        let schemeError = validateURLScheme(cleanURLScheme)
        if !schemeError.isEmpty {
            return schemeError
        }

        if !hasPendingChanges {
            if exportURL != nil {
                return "Export complete — no changes detected."
            }
            return "No changes detected."
        }

        if !bundleIDChanged && !displayNameChanged && !urlSchemeChanged {
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
            .sheet(isPresented: $showInfo) {
                InfoView(
                    currentVersion: currentAppVersion,
                    appearanceMode: $appearanceMode
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(selectedColorScheme)
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

                HStack(spacing: 8) {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Text("v\(currentAppVersion)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
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

            displayNameCard

            urlSchemeCard

            extensionCard

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
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    displayNameExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "textformat")
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Display Name")
                            .font(.headline.weight(.bold))
                        Text(cleanDisplayName.isEmpty ? "No name" : cleanDisplayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Image(systemName: displayNameExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                }
                .foregroundStyle(.primary)
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

                Text("\(cleanDisplayName.count)/30 characters")
                    .font(.caption)
                    .foregroundStyle(cleanDisplayName.count > 30 ? .red : .secondary)
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
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("URL Scheme")
                            .font(.headline.weight(.bold))
                        Text(cleanURLScheme.isEmpty ? "None" : cleanURLScheme)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    Image(systemName: urlSchemeExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            if urlSchemeExpanded {
                HStack(spacing: 8) {
                    TextField("myapp", text: $newURLScheme)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)

                    if !newURLScheme.isEmpty {
                        Button {
                            newURLScheme = ""
                            clearStaleExportState()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
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
            sectionTitle(icon: "checkmark.circle.fill", title: "Exported IPA")

            Text("Export complete.")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 10) {
                Image(systemName: "doc.zipper")
                    .foregroundStyle(.blue)

                TextField("Exported filename", text: $exportFileName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1)
                    .onSubmit {
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
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                showShareSheet = true
            } label: {
                Label("Save / Share IPA", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 18) {
                Text("Before: \(formattedFileSize(inputFileSize))")
                Text("After: \(formattedFileSize(outputFileSize))")
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
                            selectedExtensionsToRemove.isEmpty
                            ? "All \(foundExtensions.count) enabled"
                            : "\(foundExtensions.count - selectedExtensionsToRemove.count) of \(foundExtensions.count) enabled"
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
                        .foregroundStyle(
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
        displayNameExpanded = false

        originalURLScheme = ""
        newURLScheme = ""
        urlSchemeExpanded = false

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
            exportFileName = ""
            inputFileSize = 0
            outputFileSize = 0
            lastExportSignature = nil

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
            displayNameExpanded = false

            originalURLScheme = info.urlScheme
            newURLScheme = info.urlScheme
            urlSchemeExpanded = false

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
        let urlScheme: String
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

        let urlScheme = firstURLScheme(from: dict)

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
            urlScheme: urlScheme,
            extensions: extensions
        )
    }

    private func exportUpdatedIPA() {
        guard !isExporting, hasPendingChanges else {
            return
        }

        isExporting = true
        exportProgress = 0
        exportProgressText = "Preparing archive…"
        exportURL = nil
        exportSummary = ""

        if let input = ipaURL {
            inputFileSize = fileSize(of: input)
        }
        outputFileSize = 0

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

        let didChangeURLScheme =
            urlSchemeChanged

        let cleanScheme =
            cleanURLScheme

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

        let settingsSignature = currentSettingsSignature

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

                let schemeValidation = validateURLScheme(cleanScheme)
                guard schemeValidation.isEmpty else {
                    throw SimpleError(schemeValidation)
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
                                    format: nil
                                )

                        guard var dict =
                            plist as? [String: Any] else {
                            throw SimpleError(
                                "Could not edit Info.plist."
                            )
                        }

                        if isMainInfoPlist {

                            dict["CFBundleIdentifier"] =
                                cleanID

                            if !cleanName.isEmpty {
                                dict["CFBundleDisplayName"] =
                                    cleanName

                                dict["CFBundleName"] =
                                    cleanName
                            }

                            if didChangeURLScheme {
                                updateURLScheme(in: &dict, scheme: cleanScheme, bundleID: cleanID)
                            }

                        } else if shouldRewriteBundleIDs {

                            if let oldID =
                                dict["CFBundleIdentifier"]
                                as? String {

                                let lastComponent =
                                    oldID
                                        .split(
                                            separator: "."
                                        )
                                        .last
                                        ?? ""

                                dict["CFBundleIdentifier"] =
                                    cleanID +
                                    "." +
                                    lastComponent

                                rewrittenCount += 1
                            }
                        }

                        data =
                            try PropertyListSerialization
                                .data(
                                    fromPropertyList: dict,
                                    format: .xml,
                                    options: 0
                                )
                    }

                    try outputArchive.addEntry(
                        with: entry.path,
                        type: .file,
                        uncompressedSize:
                            Int64(data.count),
                        compressionMethod: .deflate,
                        provider: {
                            position,
                            size -> Data in

                            let start =
                                Int(position)

                            let end =
                                min(
                                    start + size,
                                    data.count
                                )

                            guard start < end else {
                                return Data()
                            }

                            return data.subdata(
                                in: start..<end
                            )
                        }
                    )

                    processed += 1

                    updateExportProgress(
                        progress:
                            Double(processed) /
                            Double(max(files.count, 1)),
                        text:
                            "Compressing \(processed) of \(files.count)…"
                    )
                }

                DispatchQueue.main.async {

                    rewrittenExtensions =
                        rewrittenCount

                    exportURL = output
                    exportFileName = output.lastPathComponent
                    inputFileSize = fileSize(of: input)
                    outputFileSize = fileSize(of: output)
                    lastExportSignature = settingsSignature

                    exportSummary =
                        makeExportSummary(
                            bundleIDChanged:
                                shouldRewriteBundleIDs,
                            displayNameChanged:
                                didChangeName,
                            urlSchemeChanged:
                                didChangeURLScheme,
                            removedExtensions:
                                removedExtensionCount,
                            rewrittenExtensions:
                                rewrittenCount
                        )

                    extensionsExpanded = false
                    expandedExtensionInfo = nil

                    exportProgress = 1
                    exportProgressText =
                        "Export complete."

                    isExporting = false

                    status =
                        "Export complete. Original file was not replaced."

                    UINotificationFeedbackGenerator()
                        .notificationOccurred(.success)
                }

            } catch {

                DispatchQueue.main.async {

                    isExporting = false
                    exportProgress = 0
                    exportProgressText = ""

                    exportSummary = ""

                    status =
                        "Export failed: \(error.localizedDescription)"

                    UINotificationFeedbackGenerator()
                        .notificationOccurred(.error)
                }
            }
        }
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

    private func makeReadableOutputURL(
        input: URL,
        originalName: String
    ) -> URL {

        let baseName: String

        if !originalName.isEmpty {

            baseName =
                URL(fileURLWithPath: originalName)
                    .deletingPathExtension()
                    .lastPathComponent

        } else {

            baseName =
                input
                    .deletingPathExtension()
                    .lastPathComponent
        }

        let folder =
            FileManager.default.temporaryDirectory

        var version = 1

        var candidate =
            folder.appendingPathComponent(
                "\(baseName)-bid\(version).ipa"
            )

        while FileManager.default.fileExists(
            atPath: candidate.path
        ) {

            version += 1

            candidate =
                folder.appendingPathComponent(
                    "\(baseName)-bid\(version).ipa"
                )
        }

        return candidate
    }

    private func validateURLScheme(_ scheme: String) -> String {
        let clean = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return originalURLScheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ""
                : "URL scheme cannot be empty."
        }
        if clean.count > 100 {
            return "URL scheme is too long."
        }
        if clean.contains("://") || clean.contains("/") || clean.contains(" ") {
            return "URL scheme contains invalid characters."
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+.-")
        if clean.rangeOfCharacter(from: allowed.inverted) != nil {
            return "URL scheme contains invalid characters."
        }
        guard let first = clean.first,
              first.isLetter else {
            return "URL scheme must start with a letter."
        }
        return ""
    }

    private func firstURLScheme(from dict: [String: Any]) -> String {
        guard let types = dict["CFBundleURLTypes"] as? [[String: Any]] else { return "" }
        for type in types {
            if let schemes = type["CFBundleURLSchemes"] as? [String],
               let first = schemes.first {
                return first
            }
        }
        return ""
    }

    private func updateURLScheme(in dict: inout [String: Any], scheme: String, bundleID: String) {
        if var types = dict["CFBundleURLTypes"] as? [[String: Any]], !types.isEmpty {
            if var schemes = types[0]["CFBundleURLSchemes"] as? [String], !schemes.isEmpty {
                schemes[0] = scheme
                types[0]["CFBundleURLSchemes"] = schemes
            } else {
                types[0]["CFBundleURLSchemes"] = [scheme]
            }
            dict["CFBundleURLTypes"] = types
        } else {
            dict["CFBundleURLTypes"] = [[
                "CFBundleURLName": bundleID,
                "CFBundleURLSchemes": [scheme]
            ]]
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

    private func validateBundleID(
        _ id: String
    ) -> String {

        let clean =
            id.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

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

        let allowed =
            CharacterSet(
                charactersIn:
                    "abcdefghijklmnopqrstuvwxyz" +
                    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
                    "0123456789.-"
            )

        if clean.rangeOfCharacter(
            from: allowed.inverted
        ) != nil {
            return "Bundle ID contains invalid characters."
        }

        if clean.hasPrefix(".") ||
            clean.hasSuffix(".") {

            return "Bundle ID cannot start or end with a dot."
        }

        return ""
    }

    private func makeExportSummary(
        bundleIDChanged: Bool,
        displayNameChanged: Bool,
        urlSchemeChanged: Bool,
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

        if urlSchemeChanged {
            changes.append("URL scheme changed")
        }

        if removedExtensions == 1 {
            changes.append("1 extension removed")

        } else if removedExtensions > 1 {
            changes.append(
                "\(removedExtensions) extensions removed"
            )
        }

        if rewrittenExtensions == 1 {
            changes.append(
                "1 extension ID rewritten"
            )

        } else if rewrittenExtensions > 1 {
            changes.append(
                "\(rewrittenExtensions) extension IDs rewritten"
            )
        }

        guard !changes.isEmpty else {
            return ""
        }

        return "Applied: " +
            changes.joined(separator: " • ")
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

    private func extensionRoot(
        from infoPlistPath: String
    ) -> String {

        guard let range =
            infoPlistPath.range(
                of: ".appex/"
            ) else {
            return infoPlistPath
        }

        return String(
            infoPlistPath[
                ..<range.upperBound
            ]
        )
    }

    private func extractData(
        entry: Entry,
        from archive: Archive
    ) throws -> Data {

        var data = Data()

        _ = try archive.extract(entry) {
            chunk in
            data.append(chunk)
        }

        return data
    }
}


private struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    let currentVersion: String
    @Binding var appearanceMode: String

    @State private var isCheckingForUpdate = false
    @State private var updateAlert: UpdateAlert?

    private let githubURL = URL(string: "https://github.com/shplash/IPAID")!
    private let reportIssueURL = URL(string: "https://github.com/shplash/IPAID/issues/new?template=bug_report.yml")!
    private let featureRequestURL = URL(string: "https://github.com/shplash/IPAID/issues/new?template=feature_request.yml")!

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        infoHeader

                        appearanceSection

                        linksSection

                        creditsSection

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
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
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var infoHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("IPAID")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("IPA Bundle ID Editor")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Text("v\(currentVersion)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Appearance", icon: "circle.lefthalf.filled")

            Picker("Appearance", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
        }
        .cardStyle()
    }

    private var linksSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Links", icon: "link")

            infoRow(
                title: "GitHub",
                icon: "chevron.left.forwardslash.chevron.right"
            ) {
                UIApplication.shared.open(githubURL)
            }

            Divider()
                .padding(.leading, 44)

            Button {
                checkForUpdates()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isCheckingForUpdate ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .foregroundStyle(.blue)
                        .frame(width: 24)

                    Text("Check for Updates")
                        .foregroundStyle(.primary)

                    Spacer()

                    if isCheckingForUpdate {
                        ProgressView()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .disabled(isCheckingForUpdate)

            Divider()
                .padding(.leading, 44)

            infoRow(
                title: "Report an Issue",
                icon: "ladybug"
            ) {
                UIApplication.shared.open(reportIssueURL)
            }

            Divider()
                .padding(.leading, 44)

            infoRow(
                title: "Feature Request",
                icon: "lightbulb"
            ) {
                UIApplication.shared.open(featureRequestURL)
            }
        }
        .cardStyle()
    }

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Credits", icon: "person.crop.circle")

            VStack(alignment: .leading, spacing: 5) {
                Text("IPAID")
                    .font(.headline.weight(.semibold))

                Text("Developed by shplash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Built with SwiftUI and ZIPFoundation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
        .cardStyle()
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)

            Text(title)
                .font(.headline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private func infoRow(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                    .frame(width: 24)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func checkForUpdates() {
        guard !isCheckingForUpdate else { return }

        isCheckingForUpdate = true

        Task {
            do {
                var request = URLRequest(
                    url: URL(string: "https://api.github.com/repos/shplash/IPAID/releases/latest")!
                )
                request.setValue(
                    "application/vnd.github+json",
                    forHTTPHeaderField: "Accept"
                )
                request.setValue(
                    "IPAID",
                    forHTTPHeaderField: "User-Agent"
                )

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode else {
                    throw UpdateCheckError.invalidResponse
                }

                let release = try JSONDecoder().decode(
                    GitHubRelease.self,
                    from: data
                )

                await MainActor.run {
                    isCheckingForUpdate = false

                    let latestVersion = release.tagName
                        .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

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
            } catch {
                await MainActor.run {
                    isCheckingForUpdate = false
                    updateAlert = UpdateAlert(
                        title: "Couldn't Check for Updates",
                        message: "Please check your internet connection and try again."
                    )
                }
            }
        }
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

private enum UpdateCheckError: Error {
    case invalidResponse
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(15)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                Color(
                    uiColor:
                        .secondarySystemGroupedBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 17,
                    style: .continuous
                )
            )
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

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPick: onPick
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

        init(
            onPick: @escaping (URL) -> Void
        ) {
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
