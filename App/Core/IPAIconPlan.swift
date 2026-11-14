import Foundation

struct IPAIconSlot: Equatable {
    let path: String
    let pixelWidth: Int
    let pixelHeight: Int
    let baseName: String
    let isIPad: Bool
    let isExisting: Bool
}

struct IPAIconPlan: Equatable {
    let slots: [IPAIconSlot]
    let usesAssetCatalog: Bool
    let referencedNames: [String]

    static let empty = IPAIconPlan(slots: [], usesAssetCatalog: false, referencedNames: [])

    var isEmpty: Bool {
        slots.isEmpty
    }

    var existingSlots: [IPAIconSlot] {
        slots.filter(\.isExisting)
    }

    var addedPaths: [String] {
        slots.filter { !$0.isExisting }.map(\.path)
    }

    var largestExistingSlot: IPAIconSlot? {
        existingSlots.max { $0.pixelWidth < $1.pixelWidth }
    }

    var iPhoneBaseNames: [String] {
        uniqueBaseNames(slots.filter { !$0.isIPad })
    }

    var iPadBaseNames: [String] {
        uniqueBaseNames(slots.filter(\.isIPad))
    }

    func applyingIconMetadata(to dictionary: inout [String: Any]) {
        guard slots.contains(where: { !$0.baseName.isEmpty }) else { return }

        dictionary.removeValue(forKey: "CFBundleIconName")

        if !iPhoneBaseNames.isEmpty {
            dictionary["CFBundleIconFiles"] = iPhoneBaseNames

            var icons = dictionary["CFBundleIcons"] as? [String: Any] ?? [:]
            var primary = icons["CFBundlePrimaryIcon"] as? [String: Any] ?? [:]
            primary["CFBundleIconFiles"] = iPhoneBaseNames
            primary.removeValue(forKey: "CFBundleIconName")
            icons["CFBundlePrimaryIcon"] = primary
            dictionary["CFBundleIcons"] = icons
        }

        if !iPadBaseNames.isEmpty {
            var iPadIcons = dictionary["CFBundleIcons~ipad"] as? [String: Any] ?? [:]
            var iPadPrimary = iPadIcons["CFBundlePrimaryIcon"] as? [String: Any] ?? [:]
            iPadPrimary["CFBundleIconFiles"] = iPadBaseNames
            iPadPrimary.removeValue(forKey: "CFBundleIconName")
            iPadIcons["CFBundlePrimaryIcon"] = iPadPrimary
            dictionary["CFBundleIcons~ipad"] = iPadIcons
        }
    }

    private func uniqueBaseNames(_ slots: [IPAIconSlot]) -> [String] {
        var names: [String] = []
        for slot in slots where !slot.baseName.isEmpty && !names.contains(slot.baseName) {
            names.append(slot.baseName)
        }
        return names
    }

    static func resolve(
        info: [String: Any],
        entries: [IPAEntry],
        appRoot: String,
        read: (String) throws -> Data
    ) -> IPAIconPlan {
        let directFiles = entries.filter {
            $0.kind == .file &&
            $0.path.hasPrefix(appRoot) &&
            !$0.path.dropFirst(appRoot.count).contains("/")
        }

        func names(in key: String) -> [String] {
            if let dictionary = info[key] as? [String: Any] {
                guard let primary = dictionary["CFBundlePrimaryIcon"] as? [String: Any] else {
                    return []
                }

                return (primary["CFBundleIconFiles"] as? [String]) ?? []
            }

            return (info[key] as? [String]) ?? []
        }

        var iPhoneNames = names(in: "CFBundleIcons")
        iPhoneNames.append(contentsOf: names(in: "CFBundleIconFiles"))

        if let name = info["CFBundleIconName"] as? String {
            iPhoneNames.append(name)
        }

        let iPadNames = names(in: "CFBundleIcons~ipad")
        let iPadOnlyNames = Set(iPadNames).subtracting(iPhoneNames)
        let referencedNames = iPhoneNames + iPadNames

        var slotsByPath: [String: IPAIconSlot] = [:]

        for rawName in referencedNames {
            let name = (rawName as NSString).deletingPathExtension
            let candidates = directFiles.filter { entry in
                guard (entry.path as NSString).pathExtension.lowercased() == "png" else {
                    return false
                }

                let file = (entry.path as NSString).lastPathComponent
                let base = (file as NSString).deletingPathExtension
                return base == name || base.hasPrefix(name + "@") || base.hasPrefix(name + "-")
            }

            for entry in candidates {
                if slotsByPath[entry.path] != nil { continue }
                slotsByPath[entry.path] = makeSlot(
                    path: entry.path,
                    isIPad: entry.path.contains("~ipad") || iPadOnlyNames.contains(rawName),
                    isExisting: true,
                    read: read
                )
            }
        }

        let hasLargeExistingIcon = slotsByPath.values.contains {
            $0.pixelWidth >= 120 || $0.pixelHeight >= 120
        }
        let usesAssetCatalog = info["CFBundleIconName"] != nil ||
            directFiles.contains { $0.path == appRoot + "Assets.car" }

        if slotsByPath.isEmpty || !hasLargeExistingIcon || usesAssetCatalog {
            for canonical in canonicalSlots {
                let path = appRoot + canonical.fileName
                if slotsByPath[path] != nil { continue }
                slotsByPath[path] = IPAIconSlot(
                    path: path,
                    pixelWidth: canonical.size,
                    pixelHeight: canonical.size,
                    baseName: canonical.baseName,
                    isIPad: canonical.isIPad,
                    isExisting: directFiles.contains { $0.path == path }
                )
            }
        }

        let rootFiles = entries.filter {
            $0.kind == .file &&
            !$0.path.contains("/") &&
            (($0.path as NSString).lastPathComponent.hasPrefix("iTunesArtwork"))
        }

        for entry in rootFiles {
            let size = PNGMetadata(data: (try? read(entry.path)) ?? Data())?.width ?? 1024
            slotsByPath[entry.path] = IPAIconSlot(
                path: entry.path,
                pixelWidth: size,
                pixelHeight: size,
                baseName: "",
                isIPad: false,
                isExisting: true
            )
        }

        let slots = slotsByPath.values.sorted { lhs, rhs in
            if lhs.isIPad != rhs.isIPad { return !lhs.isIPad }
            return lhs.pixelWidth < rhs.pixelWidth
        }

        return IPAIconPlan(
            slots: slots,
            usesAssetCatalog: usesAssetCatalog,
            referencedNames: referencedNames
        )
    }

    private static func makeSlot(
        path: String,
        isIPad: Bool,
        isExisting: Bool,
        read: (String) throws -> Data
    ) -> IPAIconSlot {
        let file = (path as NSString).lastPathComponent
        let base = (file as NSString).deletingPathExtension
        let pixelSize = PNGMetadata(data: (try? read(path)) ?? Data())?.width
            ?? sizeFromName(base)
            ?? 180
        let baseName = base
            .replacingOccurrences(of: "~ipad", with: "")
            .replacingOccurrences(of: "@2x", with: "")
            .replacingOccurrences(of: "@3x", with: "")

        return IPAIconSlot(
            path: path,
            pixelWidth: pixelSize,
            pixelHeight: pixelSize,
            baseName: baseName,
            isIPad: isIPad,
            isExisting: isExisting
        )
    }

    static func sizeFromName(_ name: String) -> Int? {
        func match(_ pattern: String, in value: String) -> [String]? {
            guard let expression = try? NSRegularExpression(pattern: pattern),
                  let result = expression.firstMatch(
                    in: value,
                    range: NSRange(value.startIndex..., in: value)
                  ) else {
                return nil
            }

            return (1..<result.numberOfRanges).compactMap { index in
                Range(result.range(at: index), in: value).map { String(value[$0]) }
            }
        }

        if let parts = match("(\\d+(?:\\.\\d+)?)x(\\d+(?:\\.\\d+)?)@(\\d)x", in: name),
           parts.count == 3,
           let width = Double(parts[0]),
           let scale = Int(parts[2]) {
            return Int((width * Double(scale)).rounded())
        }

        if let parts = match("(\\d+(?:\\.\\d+)?)@([23])x", in: name),
           parts.count == 2,
           let size = Double(parts[0]),
           let scale = Int(parts[1]) {
            return Int((size * Double(scale)).rounded())
        }

        return nil
    }

    private struct CanonicalIcon {
        let fileName: String
        let baseName: String
        let size: Int
        let isIPad: Bool
    }

    private static let canonicalSlots: [CanonicalIcon] = [
        CanonicalIcon(fileName: "AppIcon20x20@2x.png", baseName: "AppIcon20x20", size: 40, isIPad: false),
        CanonicalIcon(fileName: "AppIcon20x20@3x.png", baseName: "AppIcon20x20", size: 60, isIPad: false),
        CanonicalIcon(fileName: "AppIcon29x29@2x.png", baseName: "AppIcon29x29", size: 58, isIPad: false),
        CanonicalIcon(fileName: "AppIcon29x29@3x.png", baseName: "AppIcon29x29", size: 87, isIPad: false),
        CanonicalIcon(fileName: "AppIcon40x40@2x.png", baseName: "AppIcon40x40", size: 80, isIPad: false),
        CanonicalIcon(fileName: "AppIcon40x40@3x.png", baseName: "AppIcon40x40", size: 120, isIPad: false),
        CanonicalIcon(fileName: "AppIcon60x60@2x.png", baseName: "AppIcon60x60", size: 120, isIPad: false),
        CanonicalIcon(fileName: "AppIcon60x60@3x.png", baseName: "AppIcon60x60", size: 180, isIPad: false),
        CanonicalIcon(fileName: "AppIcon20x20~ipad.png", baseName: "AppIcon20x20", size: 20, isIPad: true),
        CanonicalIcon(fileName: "AppIcon29x29~ipad.png", baseName: "AppIcon29x29", size: 29, isIPad: true),
        CanonicalIcon(fileName: "AppIcon40x40~ipad.png", baseName: "AppIcon40x40", size: 40, isIPad: true),
        CanonicalIcon(fileName: "AppIcon76x76@2x~ipad.png", baseName: "AppIcon76x76", size: 152, isIPad: true),
        CanonicalIcon(fileName: "AppIcon83.5x83.5@2x~ipad.png", baseName: "AppIcon83.5x83.5", size: 167, isIPad: true)
    ]
}

struct IPAIconReplacement: Equatable {
    let imageName: String
    let previewData: Data
    let files: [String: Data]

    func validate(against plan: IPAIconPlan) -> [String] {
        var problems: [String] = []

        if plan.slots.isEmpty {
            problems.append("No icon resources were found in this IPA.")
        }

        for slot in plan.slots {
            guard let data = files[slot.path] else {
                problems.append("Missing icon \(slot.path).")
                continue
            }

            guard let metadata = PNGMetadata(data: data), metadata.isComplete else {
                problems.append("Icon \(slot.path) is not a valid PNG image.")
                continue
            }

            if metadata.width != slot.pixelWidth || metadata.height != slot.pixelHeight {
                problems.append(
                    "Icon \(slot.path) is \(metadata.width)×\(metadata.height), expected \(slot.pixelWidth)×\(slot.pixelHeight)."
                )
            }
        }

        for path in files.keys where !plan.slots.contains(where: { $0.path == path }) {
            problems.append("Unexpected icon \(path).")
        }

        return problems
    }
}
