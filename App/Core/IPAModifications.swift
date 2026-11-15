import Foundation

struct IPAModifications: Equatable {
    var bundleIdentifier: String
    var displayName: String
    var marketingVersion: String
    var buildNumber: String
    var urlScheme: String
    var removedExtensions: Set<String> = []
    var icon: IPAIconReplacement?
    var plistOverrides = InfoPlistOverrides()

    var trimmedBundleIdentifier: String {
        bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedMarketingVersion: String {
        marketingVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBuildNumber: String {
        buildNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedURLScheme: String {
        urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var fingerprint: String {
        IPASettingsFingerprint.make(self)
    }

    func bundleIdentifierChanged(from info: IPABundleInfo) -> Bool {
        trimmedBundleIdentifier != info.bundleIdentifier
    }

    func displayNameChanged(from info: IPABundleInfo) -> Bool {
        trimmedDisplayName != info.displayName
    }

    func marketingVersionChanged(from info: IPABundleInfo) -> Bool {
        trimmedMarketingVersion != info.marketingVersion
    }

    func buildNumberChanged(from info: IPABundleInfo) -> Bool {
        trimmedBuildNumber != info.buildNumber
    }

    func urlSchemeChanged(from info: IPABundleInfo) -> Bool {
        trimmedURLScheme != info.urlScheme.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func hasChanges(from info: IPABundleInfo) -> Bool {
        bundleIdentifierChanged(from: info) ||
            displayNameChanged(from: info) ||
            marketingVersionChanged(from: info) ||
            buildNumberChanged(from: info) ||
            urlSchemeChanged(from: info) ||
            !removedExtensions.isEmpty ||
            icon != nil ||
            !plistOverrides.isEmpty
    }

    func problems(comparedTo info: IPABundleInfo) -> [String] {
        var problems: [String] = []

        if bundleIdentifierChanged(from: info) || trimmedBundleIdentifier.isEmpty {
            appendProblem(MetadataValidation.bundleIdentifier(trimmedBundleIdentifier), to: &problems)
        }

        if displayNameChanged(from: info) {
            appendProblem(MetadataValidation.displayName(trimmedDisplayName), to: &problems)
        }

        if marketingVersionChanged(from: info) {
            appendProblem(MetadataValidation.marketingVersion(trimmedMarketingVersion), to: &problems)
        }

        if buildNumberChanged(from: info) {
            appendProblem(MetadataValidation.buildNumber(trimmedBuildNumber), to: &problems)
        }

        if urlSchemeChanged(from: info) || !info.urlScheme.isEmpty {
            appendProblem(
                MetadataValidation.urlScheme(
                    trimmedURLScheme,
                    allowEmpty: info.urlScheme.isEmpty
                ),
                to: &problems
            )
        }

        for root in removedExtensions.sorted() where !info.extensions.contains(where: { $0.root == root }) {
            problems.append("Unknown app extension.")
        }

        for key in plistOverrides.values.keys.sorted() where ProtectedPlistKeys.isProtected(key) {
            problems.append("\(key) is managed by IPAID and cannot be overridden.")
        }

        for key in plistOverrides.removedKeys.sorted() where ProtectedPlistKeys.isProtected(key) {
            problems.append("\(key) is required and cannot be removed.")
        }

        if let icon {
            problems.append(contentsOf: icon.validate(against: info.iconPlan))
        }

        var seen = Set<String>()
        return problems.filter { seen.insert($0).inserted }
    }

    private func appendProblem(_ message: String, to problems: inout [String]) {
        if !message.isEmpty {
            problems.append(message)
        }
    }
}

struct IPAModificationChange: Identifiable, Equatable {
    let id: String
    let label: String
    let original: String
    let updated: String
}

struct IPAModificationSummary: Equatable {
    var changes: [IPAModificationChange]
    var removedFiles: [String]
    var addedFiles: [String]
    var modifiedFiles: [String]
    var iconFilePaths: [String]
    var warnings: [String]

    var isEmpty: Bool {
        changes.isEmpty && removedFiles.isEmpty && addedFiles.isEmpty && modifiedFiles.isEmpty
    }

    init(
        info: IPABundleInfo,
        entries: [IPAEntry],
        modifications: IPAModifications
    ) {
        var changes: [IPAModificationChange] = []
        var modifiedFiles: [String] = []
        var warnings: [String] = []

        if modifications.bundleIdentifierChanged(from: info) {
            changes.append(
                IPAModificationChange(
                    id: "bundleIdentifier",
                    label: "Bundle ID",
                    original: info.bundleIdentifier,
                    updated: modifications.trimmedBundleIdentifier
                )
            )
        }

        if modifications.displayNameChanged(from: info) {
            changes.append(
                IPAModificationChange(
                    id: "displayName",
                    label: "Display name",
                    original: info.displayName,
                    updated: modifications.trimmedDisplayName
                )
            )
        }

        if modifications.marketingVersionChanged(from: info) {
            changes.append(
                IPAModificationChange(
                    id: "marketingVersion",
                    label: "Marketing version",
                    original: info.marketingVersion.isEmpty ? "None" : info.marketingVersion,
                    updated: modifications.trimmedMarketingVersion
                )
            )
            warnings.append("In-app version text is not changed.")
        }

        if modifications.buildNumberChanged(from: info) {
            changes.append(
                IPAModificationChange(
                    id: "buildNumber",
                    label: "Build number",
                    original: info.buildNumber.isEmpty ? "None" : info.buildNumber,
                    updated: modifications.trimmedBuildNumber
                )
            )
        }

        if modifications.urlSchemeChanged(from: info) {
            changes.append(
                IPAModificationChange(
                    id: "urlScheme",
                    label: "URL scheme",
                    original: info.urlScheme.isEmpty ? "None" : info.urlScheme,
                    updated: modifications.trimmedURLScheme.isEmpty ? "None" : modifications.trimmedURLScheme
                )
            )
        }

        if !modifications.removedExtensions.isEmpty {
            changes.append(
                IPAModificationChange(
                    id: "extensions",
                    label: "Extensions",
                    original: "\(info.extensions.count)",
                    updated: "\(info.extensions.count - modifications.removedExtensions.count)"
                )
            )
        }

        if let icon = modifications.icon {
            changes.append(
                IPAModificationChange(
                    id: "icon",
                    label: "Icon",
                    original: info.iconPlan.existingSlots.isEmpty ? "Bundled icon" : "Original icon",
                    updated: "\(icon.imageName) (\(icon.files.count) files)"
                )
            )

            if info.iconPlan.usesAssetCatalog {
                warnings.append("Icons inside Assets.car cannot be replaced; IPAID adds loose icon files instead.")
            }
        }

        if !modifications.plistOverrides.isEmpty {
            changes.append(
                IPAModificationChange(
                    id: "advanced",
                    label: "Info.plist",
                    original: "App settings",
                    updated: "\(modifications.plistOverrides.changeCount) edits"
                )
            )
        }

        let removedFiles = entries
            .filter { entry in
                modifications.removedExtensions.contains { root in
                    entry.path.hasPrefix(root)
                }
            }
            .map(\.path)

        let addedFiles = modifications.icon == nil
            ? [String]()
            : info.iconPlan.slots.filter { !$0.isExisting }.map(\.path)

        if modifications.bundleIdentifierChanged(from: info) ||
            modifications.displayNameChanged(from: info) ||
            modifications.marketingVersionChanged(from: info) ||
            modifications.buildNumberChanged(from: info) ||
            modifications.urlSchemeChanged(from: info) ||
            !modifications.plistOverrides.isEmpty ||
            modifications.icon != nil {
            modifiedFiles.append(info.infoPlistPath)
        }

        if modifications.bundleIdentifierChanged(from: info) {
            for item in info.extensions where !modifications.removedExtensions.contains(item.root) {
                modifiedFiles.append(item.infoPlistPath)
            }
        }

        if let icon = modifications.icon {
            for slot in info.iconPlan.existingSlots where icon.files[slot.path] != nil {
                modifiedFiles.append(slot.path)
            }
        }

        self.changes = changes
        self.removedFiles = removedFiles
        self.addedFiles = addedFiles
        self.modifiedFiles = Array(Set(modifiedFiles)).sorted()
        self.iconFilePaths = Array(
            Set(addedFiles + modifiedFiles)
                .intersection(Set(info.iconPlan.slots.map(\.path)))
        ).sorted()
        self.warnings = warnings
    }
}
