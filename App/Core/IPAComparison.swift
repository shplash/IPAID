import Foundation

struct IPAMetadataDifference: Identifiable, Equatable {
    let id: String
    let label: String
    let left: String
    let right: String

    var isDifferent: Bool {
        left != right
    }
}

struct IPAComparisonResult: Equatable {
    let leftName: String
    let rightName: String
    let metadata: [IPAMetadataDifference]
    let addedFiles: [String]
    let removedFiles: [String]
    let changedFiles: [String]
    let leftFileCount: Int
    let rightFileCount: Int

    var differingMetadata: [IPAMetadataDifference] {
        metadata.filter(\.isDifferent)
    }

    var hasDifferences: Bool {
        !differingMetadata.isEmpty ||
            !addedFiles.isEmpty ||
            !removedFiles.isEmpty ||
            !changedFiles.isEmpty
    }
}

enum IPAComparison {

    static func compare(
        left: IPAArchive,
        leftName: String,
        right: IPAArchive,
        rightName: String
    ) -> IPAComparisonResult {
        let leftInfo = left.info
        let rightInfo = right.info

        func value(_ text: String) -> String {
            text.isEmpty ? "None" : text
        }

        let metadata: [IPAMetadataDifference] = [
            IPAMetadataDifference(
                id: "name",
                label: "App name",
                left: value(leftInfo.displayName),
                right: value(rightInfo.displayName)
            ),
            IPAMetadataDifference(
                id: "bundleIdentifier",
                label: "Bundle ID",
                left: leftInfo.bundleIdentifier,
                right: rightInfo.bundleIdentifier
            ),
            IPAMetadataDifference(
                id: "marketingVersion",
                label: "Marketing version",
                left: value(leftInfo.marketingVersion),
                right: value(rightInfo.marketingVersion)
            ),
            IPAMetadataDifference(
                id: "buildNumber",
                label: "Build number",
                left: value(leftInfo.buildNumber),
                right: value(rightInfo.buildNumber)
            ),
            IPAMetadataDifference(
                id: "minimumOSVersion",
                label: "Minimum iOS",
                left: value(leftInfo.minimumOSVersion),
                right: value(rightInfo.minimumOSVersion)
            ),
            IPAMetadataDifference(
                id: "executable",
                label: "Executable",
                left: value(leftInfo.executable),
                right: value(rightInfo.executable)
            ),
            IPAMetadataDifference(
                id: "architectures",
                label: "Architectures",
                left: value(leftInfo.architectures.joined(separator: ", ")),
                right: value(rightInfo.architectures.joined(separator: ", "))
            ),
            IPAMetadataDifference(
                id: "extensions",
                label: "Extensions",
                left: "\(leftInfo.extensions.count)",
                right: "\(rightInfo.extensions.count)"
            ),
            IPAMetadataDifference(
                id: "extensionIDs",
                label: "Extension IDs",
                left: extensionIDs(leftInfo),
                right: extensionIDs(rightInfo)
            ),
            IPAMetadataDifference(
                id: "size",
                label: "File size",
                left: ByteCountFormatter.string(fromByteCount: leftInfo.fileSize, countStyle: .file),
                right: ByteCountFormatter.string(fromByteCount: rightInfo.fileSize, countStyle: .file)
            )
        ]

        let leftFiles = fileMap(left)
        let rightFiles = fileMap(right)

        let added = rightFiles.keys.filter { leftFiles[$0] == nil }.sorted()
        let removed = leftFiles.keys.filter { rightFiles[$0] == nil }.sorted()
        let changed = leftFiles.keys
            .filter { path in
                guard let right = rightFiles[path], let left = leftFiles[path] else {
                    return false
                }
                return left != right
            }
            .sorted()

        return IPAComparisonResult(
            leftName: leftName,
            rightName: rightName,
            metadata: metadata,
            addedFiles: added,
            removedFiles: removed,
            changedFiles: changed,
            leftFileCount: leftFiles.count,
            rightFileCount: rightFiles.count
        )
    }

    private static func extensionIDs(_ info: IPABundleInfo) -> String {
        let identifiers = info.extensions
            .map(\.bundleIdentifier)
            .filter { !$0.isEmpty }
            .sorted()

        return identifiers.isEmpty ? "None" : identifiers.joined(separator: ", ")
    }

    private struct FileFingerprint: Equatable {
        let checksum: UInt32
        let size: Int
        let compressedSize: Int
    }

    private static func fileMap(_ archive: IPAArchive) -> [String: FileFingerprint] {
        var result: [String: FileFingerprint] = [:]

        for entry in archive.entries where entry.kind != .directory {
            result[entry.path] = FileFingerprint(
                checksum: entry.checksum,
                size: entry.uncompressedSize,
                compressedSize: entry.compressedSize
            )
        }

        return result
    }
}
