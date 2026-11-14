import Foundation

struct IPAVersionReference: Equatable {
    let path: String
    let value: String
}

enum IPAVersionReferenceScanner {
    private static let textExtensions: Set<String> = [
        "plist", "json", "strings", "stringsdict", "txt", "xml",
        "conf", "yml", "yaml", "properties", "js", "html"
    ]

    static func scan(
        archive: IPAArchive,
        maxFileSize: Int = 512 * 1024,
        limit: Int = 40
    ) -> [IPAVersionReference] {
        let version = archive.info.marketingVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !version.isEmpty else {
            return []
        }

        var references: [IPAVersionReference] = []

        for entry in archive.entries where entry.kind == .file {
            guard entry.path.hasPrefix(archive.info.appRoot),
                  entry.path != archive.info.infoPlistPath,
                  entry.uncompressedSize > 0,
                  entry.uncompressedSize <= maxFileSize else {
                continue
            }

            if entry.path.contains(".framework/") || entry.path.contains(".appex/") {
                continue
            }

            let pathExtension = (entry.path as NSString).pathExtension.lowercased()

            guard textExtensions.contains(pathExtension),
                  let data = try? archive.data(at: entry.path),
                  !data.contains(0),
                  let text = String(data: data, encoding: .utf8),
                  text.contains(version) else {
                continue
            }

            references.append(IPAVersionReference(path: entry.path, value: version))

            if references.count >= limit {
                break
            }
        }

        return references
    }
}
