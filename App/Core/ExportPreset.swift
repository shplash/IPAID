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

    init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String? = nil,
        displayName: String? = nil,
        marketingVersion: String? = nil,
        buildNumber: String? = nil,
        urlScheme: String? = nil,
        removedExtensions: [String]? = nil,
        createdAt: Date = Date()
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
            removedExtensions: extensions.isEmpty ? nil : extensions
        )
    }

    func apply(
        to modifications: inout IPAModifications,
        availableExtensions: [IPAExtensionInfo]
    ) {
        if let bundleIdentifier {
            modifications.bundleIdentifier = bundleIdentifier
        }

        if let displayName {
            modifications.displayName = displayName
        }

        if let marketingVersion {
            modifications.marketingVersion = marketingVersion
        }

        if let buildNumber {
            modifications.buildNumber = buildNumber
        }

        if let urlScheme {
            modifications.urlScheme = urlScheme
        }

        if let removedExtensions {
            let available = Set(availableExtensions.map(\.root))
            modifications.removedExtensions = Set(
                removedExtensions.filter { available.contains($0) }
            )
        }
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
