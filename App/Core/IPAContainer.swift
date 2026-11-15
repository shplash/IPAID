import Foundation
import ZIPFoundation

struct IPAEntry: Equatable {
    enum Kind: String {
        case file
        case directory
        case symlink
    }

    let path: String
    let kind: Kind
    let uncompressedSize: Int
    let compressedSize: Int
    let checksum: UInt32
    let modificationDate: Date?
    let permissions: UInt16?

    init(entry: Entry) {
        path = entry.path

        switch entry.type {
        case .directory: kind = .directory
        case .symlink: kind = .symlink
        default: kind = .file
        }

        uncompressedSize = Int(entry.uncompressedSize)
        compressedSize = Int(entry.compressedSize)
        checksum = entry.checksum
        modificationDate = entry.fileAttributes[.modificationDate] as? Date
        permissions = (entry.fileAttributes[.posixPermissions] as? NSNumber)?.uint16Value
    }
}

private struct IPAPrefixComplete: Error {}

final class IPAArchive {
    let url: URL
    let entries: [IPAEntry]
    let info: IPABundleInfo
    let infoPlist: [String: Any]
    let infoPlistFormat: PropertyListSerialization.PropertyListFormat

    private let archive: Archive
    private let sources: [String: Entry]

    init(url: URL) throws {
        self.url = url

        let opened: Archive

        do {
            opened = try Archive(url: url, accessMode: .read)
        } catch {
            throw IPAError.unreadableArchive
        }

        archive = opened

        let list = opened.map(IPAEntry.init)
        entries = list

        var lookup: [String: Entry] = [:]
        for entry in opened where lookup[entry.path] == nil {
            lookup[entry.path] = entry
        }
        sources = lookup

        guard let infoPoint = Self.locateAppBundle(in: list) else {
            throw IPAError.missingInfoPlist
        }
        guard let plistEntry = lookup[infoPoint.plistPath] else {
            throw IPAError.missingInfoPlist
        }

        let plistData = try Self.extract(plistEntry, from: opened)
        var format = PropertyListSerialization.PropertyListFormat.xml
        let parsed = try PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: &format
        )

        guard let dictionary = parsed as? [String: Any] else {
            throw IPAError.invalidInfoPlist
        }

        guard let bundleIdentifier = dictionary["CFBundleIdentifier"] as? String,
              !bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IPAError.invalidBundleIdentifier
        }

        infoPlist = dictionary
        infoPlistFormat = format

        let executable = dictionary["CFBundleExecutable"] as? String ?? ""
        let architectures: [String]

        if !executable.isEmpty,
           let executableEntry = lookup[infoPoint.appRoot + executable] {
            let prefix = try Self.prefix(of: executableEntry, from: opened, limit: 4096)
            architectures = MachOArchitectures.parse(data: prefix)
        } else {
            architectures = []
        }

        let extensions = try Self.readExtensions(
            entries: list,
            appRoot: infoPoint.appRoot,
            archive: opened,
            sources: lookup
        )

        let iconPlan = IPAIconPlan.resolve(
            info: dictionary,
            entries: list,
            appRoot: infoPoint.appRoot,
            read: { path in
                guard let entry = lookup[path] else {
                    throw IPAError.missingEntry(path)
                }
                return try Self.extract(entry, from: opened)
            }
        )

        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0

        info = IPABundleInfo(
            appRoot: infoPoint.appRoot,
            infoPlistPath: infoPoint.plistPath,
            bundleIdentifier: bundleIdentifier,
            displayName: IPABundleParsing.displayName(from: dictionary, appRoot: infoPoint.appRoot),
            bundleName: dictionary["CFBundleName"] as? String ?? "",
            marketingVersion: dictionary["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: dictionary["CFBundleVersion"] as? String ?? "",
            minimumOSVersion: dictionary["MinimumOSVersion"] as? String ?? "",
            executable: executable,
            urlScheme: IPABundleParsing.firstURLScheme(from: dictionary),
            extensions: extensions,
            iconPlan: iconPlan,
            architectures: architectures,
            fileSize: size,
            targetSDK: IPABundleParsing.targetSDK(from: dictionary),
            deviceFamilies: IPABundleParsing.deviceFamilies(from: dictionary),
            isSigned: IPABundleParsing.isSigned(entries: list, appRoot: infoPoint.appRoot)
        )
    }

    func data(at path: String) throws -> Data {
        guard let entry = sources[path] else {
            throw IPAError.missingEntry(path)
        }

        if entry.type == .directory {
            return Data()
        }

        return try Self.extract(entry, from: archive)
    }

    func entry(at path: String) -> Entry? {
        sources[path]
    }

    func infoDictionary(at path: String) throws -> [String: Any] {
        let data = try data(at: path)
        let parsed = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )

        guard let dictionary = parsed as? [String: Any] else {
            throw IPAError.invalidInfoPlist
        }

        return dictionary
    }

    static func plistFormat(of data: Data) -> PropertyListSerialization.PropertyListFormat {
        var format = PropertyListSerialization.PropertyListFormat.xml
        _ = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: &format
        )
        return format
    }

    static func serialize(
        _ dictionary: [String: Any],
        format: PropertyListSerialization.PropertyListFormat
    ) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: format,
            options: 0
        )
    }

    static func locateAppBundle(in entries: [IPAEntry]) -> (appRoot: String, plistPath: String)? {
        let candidates = entries.compactMap { entry -> (appRoot: String, plistPath: String)? in
            let parts = entry.path.split(separator: "/").map(String.init)
            guard parts.count >= 3,
                  parts[parts.count - 3] == "Payload",
                  parts[parts.count - 2].hasSuffix(".app"),
                  parts[parts.count - 1] == "Info.plist" else {
                return nil
            }

            let plistPath = entry.path
            let appRoot = String(
                plistPath.dropLast("Info.plist".count)
            )
            return (appRoot: appRoot, plistPath: plistPath)
        }

        return candidates.min { lhs, rhs in
            lhs.appRoot.split(separator: "/").count < rhs.appRoot.split(separator: "/").count
        }
    }

    private static func readExtensions(
        entries: [IPAEntry],
        appRoot: String,
        archive: Archive,
        sources: [String: Entry]
    ) throws -> [IPAExtensionInfo] {
        var roots: [String] = []

        for entry in entries where entry.path.hasPrefix(appRoot) {
            guard let range = entry.path.range(of: ".appex/") else { continue }
            let root = String(entry.path[..<range.upperBound])
            if !roots.contains(root) {
                roots.append(root)
            }
        }

        var result: [IPAExtensionInfo] = []

        for root in roots.sorted() {
            let plistPath = root + "Info.plist"
            guard let plistEntry = sources[plistPath],
                  let data = try? extract(plistEntry, from: archive),
                  let parsed = try? PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                  ),
                  let dictionary = parsed as? [String: Any] else {
                continue
            }

            result.append(
                IPAExtensionInfo(
                    root: root,
                    infoPlistPath: plistPath,
                    bundleIdentifier: dictionary["CFBundleIdentifier"] as? String ?? "",
                    displayName: IPABundleParsing.displayName(from: dictionary, appRoot: root),
                    extensionPointIdentifier: extensionPointIdentifier(in: dictionary)
                )
            )
        }

        return result
    }

    private static func extensionPointIdentifier(in dictionary: [String: Any]) -> String {
        guard let extensionInfo = dictionary["NSExtension"] as? [String: Any],
              let identifier = extensionInfo["NSExtensionPointIdentifier"] as? String else {
            return ""
        }

        return identifier
    }

    private static func extract(_ entry: Entry, from archive: Archive) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    private static func prefix(of entry: Entry, from archive: Archive, limit: Int) throws -> Data {
        var data = Data()

        do {
            _ = try archive.extract(entry) { chunk in
                let remaining = limit - data.count
                data.append(chunk.prefix(max(remaining, 0)))

                if data.count >= limit {
                    throw IPAPrefixComplete()
                }
            }
        } catch is IPAPrefixComplete {
        }

        return data
    }
}
