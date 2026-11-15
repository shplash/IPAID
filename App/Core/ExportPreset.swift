import Foundation

struct ExportPreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var bundleIdentifier: String?
    var displayName: String?
    var marketingVersion: String?
    var buildNumber: String?
    var urlScheme: String?
    var removedExtensions: [String]?
    var createdAt: Date
    var sourceBundleIdentifier: String?

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        displayName: String? = nil,
        marketingVersion: String? = nil,
        buildNumber: String? = nil,
        urlScheme: String? = nil,
        removedExtensions: [String]? = nil,
        createdAt: Date = Date(),
        sourceBundleIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
        self.urlScheme = urlScheme
        self.removedExtensions = removedExtensions
        self.createdAt = createdAt
        self.sourceBundleIdentifier = sourceBundleIdentifier
    }

    var fieldCount: Int {
        var count = 0

        if bundleIdentifier != nil { count += 1 }
        if displayName != nil { count += 1 }
        if marketingVersion != nil { count += 1 }
        if buildNumber != nil { count += 1 }
        if urlScheme != nil { count += 1 }
        if let removedExtensions, !removedExtensions.isEmpty { count += 1 }

        return count
    }

    static func make(
        from modifications: IPAModifications,
        info: IPABundleInfo,
        name: String,
        availableExtensions: [IPAExtensionInfo]
    ) -> ExportPreset {
        let extensions = modifications.removedExtensions
            .filter { root in availableExtensions.contains(where: { $0.root == root }) }
            .sorted()

        return ExportPreset(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bundleIdentifier: modifications.bundleIdentifierChanged(from: info)
                ? modifications.trimmedBundleIdentifier
                : nil,
            displayName: modifications.displayNameChanged(from: info)
                ? modifications.trimmedDisplayName
                : nil,
            marketingVersion: modifications.marketingVersionChanged(from: info)
                ? modifications.trimmedMarketingVersion
                : nil,
            buildNumber: modifications.buildNumberChanged(from: info)
                ? modifications.trimmedBuildNumber
                : nil,
            urlScheme: modifications.urlSchemeChanged(from: info)
                ? modifications.trimmedURLScheme
                : nil,
            removedExtensions: extensions.isEmpty ? nil : extensions,
            sourceBundleIdentifier: info.bundleIdentifier
        )
    }

    func plan(
        applyingTo modifications: IPAModifications,
        info: IPABundleInfo
    ) -> ExportPresetPlan {
        var updated = modifications
        var changes: [IPAModificationChange] = []
        var warnings: [String] = []

        if let bundleIdentifier, !bundleIdentifier.isEmpty,
           bundleIdentifier != modifications.trimmedBundleIdentifier {
            updated.bundleIdentifier = bundleIdentifier
            changes.append(
                IPAModificationChange(
                    id: "bundleIdentifier",
                    label: "Bundle ID",
                    original: modifications.trimmedBundleIdentifier,
                    updated: bundleIdentifier
                )
            )
        }

        if let displayName, !displayName.isEmpty,
           displayName != modifications.trimmedDisplayName {
            updated.displayName = displayName
            changes.append(
                IPAModificationChange(
                    id: "displayName",
                    label: "Display name",
                    original: modifications.trimmedDisplayName,
                    updated: displayName
                )
            )
        }

        if let marketingVersion, marketingVersion != modifications.trimmedMarketingVersion {
            updated.marketingVersion = marketingVersion
            changes.append(
                IPAModificationChange(
                    id: "marketingVersion",
                    label: "Marketing version",
                    original: modifications.trimmedMarketingVersion,
                    updated: marketingVersion
                )
            )
        }

        if let buildNumber, buildNumber != modifications.trimmedBuildNumber {
            updated.buildNumber = buildNumber
            changes.append(
                IPAModificationChange(
                    id: "buildNumber",
                    label: "Build number",
                    original: modifications.trimmedBuildNumber,
                    updated: buildNumber
                )
            )
        }

        if let urlScheme, urlScheme != modifications.trimmedURLScheme {
            updated.urlScheme = urlScheme
            changes.append(
                IPAModificationChange(
                    id: "urlScheme",
                    label: "URL scheme",
                    original: modifications.trimmedURLScheme.isEmpty ? "None" : modifications.trimmedURLScheme,
                    updated: urlScheme.isEmpty ? "None" : urlScheme
                )
            )
        }

        if let removedExtensions {
            let available = Set(info.extensions.map(\.root))
            let kept = removedExtensions.filter { available.contains($0) }
            let skipped = removedExtensions.count - kept.count

            if !kept.isEmpty {
                updated.removedExtensions = Set(kept)
                changes.append(
                    IPAModificationChange(
                        id: "extensions",
                        label: "Extensions",
                        original: "\(info.extensions.count) in this app",
                        updated: "\(info.extensions.count - kept.count) kept, \(kept.count) removed"
                    )
                )
            }

            if skipped == 1 {
                warnings.append("1 saved extension is not in this app and will be skipped.")
            } else if skipped > 1 {
                warnings.append("\(skipped) saved extensions are not in this app and will be skipped.")
            }
        }

        let source = (sourceBundleIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !source.isEmpty, source != info.bundleIdentifier {
            warnings.insert(
                "Saved from \(source). Check these changes before applying them to \(info.bundleIdentifier).",
                at: 0
            )
        }

        return ExportPresetPlan(
            modifications: updated,
            changes: changes,
            warnings: warnings
        )
    }
}

struct ExportPresetPlan {
    let modifications: IPAModifications
    let changes: [IPAModificationChange]
    let warnings: [String]

    var isEmpty: Bool {
        changes.isEmpty
    }
}

final class ExportPresetStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "ipaidExportPresets") {
        self.defaults = defaults
        self.key = key
    }

    func presets() -> [ExportPreset] {
        guard let data = defaults.data(forKey: key),
              let presets = try? JSONDecoder().decode([ExportPreset].self, from: data) else {
            return []
        }

        return presets.sorted { $0.createdAt > $1.createdAt }
    }

    func save(_ presets: [ExportPreset]) {
        guard let data = try? JSONEncoder().encode(presets) else {
            return
        }

        defaults.set(data, forKey: key)
    }

    func add(
        name: String,
        from modifications: IPAModifications,
        info: IPABundleInfo,
        availableExtensions: [IPAExtensionInfo]
    ) -> [ExportPreset] {
        var all = presets()
        all.insert(
            ExportPreset.make(
                from: modifications,
                info: info,
                name: name,
                availableExtensions: availableExtensions
            ),
            at: 0
        )
        save(all)
        return all
    }

    func remove(_ preset: ExportPreset) -> [ExportPreset] {
        let all = presets().filter { $0.id != preset.id }
        save(all)
        return all
    }
}
