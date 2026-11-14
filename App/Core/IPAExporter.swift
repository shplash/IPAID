import Foundation
import ZIPFoundation

struct IPAExportRequest {
    let sourceURL: URL
    let outputURL: URL
    let modifications: IPAModifications
}

struct IPAExportResult {
    let outputURL: URL
    let entryCount: Int
    let fileSize: Int64
    let summary: IPAModificationSummary
}

enum IPAExporter {

    static func export(
        _ request: IPAExportRequest,
        progress: ((Double, String) -> Void)? = nil
    ) throws -> IPAExportResult {
        guard request.sourceURL.standardizedFileURL != request.outputURL.standardizedFileURL else {
            throw IPAError.exportFailed("The exported IPA cannot replace the original file.")
        }

        let source = try IPAArchive(url: request.sourceURL)
        let info = source.info
        let modifications = request.modifications
        let problems = modifications.problems(comparedTo: info)

        guard problems.isEmpty else {
            throw IPAError.validationFailed(problems)
        }

        guard modifications.hasChanges(from: info) else {
            throw IPAError.exportFailed("No changes to export.")
        }

        var mainPlist = source.infoPlist

        mainPlist["CFBundleIdentifier"] = modifications.trimmedBundleIdentifier

        if modifications.displayNameChanged(from: info) {
            mainPlist["CFBundleDisplayName"] = modifications.trimmedDisplayName
            mainPlist["CFBundleName"] = modifications.trimmedDisplayName
        }

        if modifications.marketingVersionChanged(from: info) {
            mainPlist["CFBundleShortVersionString"] = modifications.trimmedMarketingVersion
        }

        if modifications.buildNumberChanged(from: info) {
            mainPlist["CFBundleVersion"] = modifications.trimmedBuildNumber
        }

        if modifications.bundleIdentifierChanged(from: info),
           var types = mainPlist["CFBundleURLTypes"] as? [[String: Any]] {
            for index in types.indices {
                if types[index]["CFBundleURLName"] as? String == info.bundleIdentifier {
                    types[index]["CFBundleURLName"] = modifications.trimmedBundleIdentifier
                }
            }
            mainPlist["CFBundleURLTypes"] = types
        }

        if modifications.urlSchemeChanged(from: info) {
            IPABundleParsing.updateURLScheme(
                in: &mainPlist,
                scheme: modifications.trimmedURLScheme,
                bundleIdentifier: modifications.trimmedBundleIdentifier
            )
        }

        modifications.plistOverrides.apply(to: &mainPlist)

        if modifications.icon != nil {
            info.iconPlan.applyingIconMetadata(to: &mainPlist)
        }

        let mainPlistData = try IPAArchive.serialize(mainPlist, format: source.infoPlistFormat)

        var extensionData: [String: Data] = [:]

        if modifications.bundleIdentifierChanged(from: info) {
            for item in info.extensions where !modifications.removedExtensions.contains(item.root) {
                guard var dictionary = try? source.infoDictionary(at: item.infoPlistPath) else {
                    continue
                }

                let lastComponent = item.bundleIdentifier
                    .split(separator: ".")
                    .last
                    .map(String.init)

                dictionary["CFBundleIdentifier"] = modifications.trimmedBundleIdentifier +
                    "." + (lastComponent ?? "extension")

                let format = IPAArchive.plistFormat(
                    of: (try? source.data(at: item.infoPlistPath)) ?? Data()
                )
                extensionData[item.infoPlistPath] = try IPAArchive.serialize(
                    dictionary,
                    format: format
                )
            }
        }

        let iconFiles = modifications.icon?.files ?? [:]
        let executablePath = info.executablePath
        let outputURL = request.outputURL

        let fileManager = FileManager.default
        let directory = outputURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw IPAError.exportFailed("Could not create the export folder.")
        }

        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        var remainingPaths: Set<String> = []
        var written = 0
        let directoryPermissions: UInt16 = 0o755

        do {
            let output = try Archive(url: outputURL, accessMode: .create)
            let total = max(source.entries.count, 1)

            for entry in source.entries {
                let timestamp: Date = entry.modificationDate ?? Date()
                let isRemoved = modifications.removedExtensions.contains { root in
                    entry.path.hasPrefix(root)
                }

                if isRemoved {
                    continue
                }

                if entry.kind == .directory {
                    let permissionsValue: UInt16
                    if let existing = entry.permissions {
                        permissionsValue = existing
                    } else {
                        permissionsValue = directoryPermissions
                    }

                    try output.addEntry(
                        with: entry.path,
                        type: .directory,
                        uncompressedSize: Int64(0),
                        modificationDate: timestamp,
                        permissions: permissionsValue,
                        provider: { (_: Int64, _: Int) in Data() }
                    )

                    remainingPaths.insert(entry.path)
                    written += 1
                    progress?(Double(written) / Double(total), "Packaging \(written) of \(source.entries.count)…")
                    continue
                }

                let data: Data

                if entry.path == info.infoPlistPath {
                    data = mainPlistData
                } else if let replacement = extensionData[entry.path] {
                    data = replacement
                } else if let replacement = iconFiles[entry.path] {
                    data = replacement
                } else {
                    data = try source.data(at: entry.path)
                }

                let permissions = permissions(
                    for: entry,
                    path: entry.path,
                    executablePath: executablePath
                )

                try output.addEntry(
                    with: entry.path,
                    type: entry.kind == .symlink ? .symlink : .file,
                    uncompressedSize: Int64(data.count),
                    modificationDate: timestamp,
                    permissions: permissions,
                    compressionMethod: .deflate,
                    provider: provider(for: data)
                )

                remainingPaths.insert(entry.path)
                written += 1
                progress?(Double(written) / Double(total), "Packaging \(written) of \(source.entries.count)…")
            }

            for slot in info.iconPlan.slots where !slot.isExisting {
                guard let data = iconFiles[slot.path] else { continue }
                guard !remainingPaths.contains(slot.path) else { continue }

                try output.addEntry(
                    with: slot.path,
                    type: .file,
                    uncompressedSize: Int64(data.count),
                    permissions: 0o644,
                    compressionMethod: .deflate,
                    provider: provider(for: data)
                )

                remainingPaths.insert(slot.path)
            }

            let expectedPaths = remainingPaths
            try validate(
                url: outputURL,
                expectedBundleIdentifier: modifications.trimmedBundleIdentifier,
                expectedVersion: modifications.marketingVersionChanged(from: info)
                    ? modifications.trimmedMarketingVersion
                    : nil,
                expectedBuild: modifications.buildNumberChanged(from: info)
                    ? modifications.trimmedBuildNumber
                    : nil,
                plan: modifications.icon == nil ? nil : info.iconPlan,
                expectedPaths: expectedPaths
            )

            let result = IPAExportResult(
                outputURL: outputURL,
                entryCount: expectedPaths.count,
                fileSize: fileSize(of: outputURL),
                summary: IPAModificationSummary(
                    info: info,
                    entries: source.entries,
                    modifications: modifications
                )
            )

            progress?(1, "Export complete.")
            return result
        } catch {
            try? fileManager.removeItem(at: outputURL)
            throw error
        }
    }

    private static func provider(for data: Data) -> Provider {
        { position, size in
            let start = Int(position)
            let end = min(start + size, data.count)

            guard start < end else {
                return Data()
            }

            return data.subdata(in: start..<end)
        }
    }

    private static func permissions(
        for entry: IPAEntry,
        path: String,
        executablePath: String
    ) -> UInt16 {
        if path == executablePath {
            return 0o755
        }

        if entry.kind == .symlink {
            return 0o777
        }

        if let permissions = entry.permissions, permissions != 0 {
            return permissions
        }

        return 0o644
    }

    private static func fileSize(of url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func validate(
        url: URL,
        expectedBundleIdentifier: String,
        expectedVersion: String?,
        expectedBuild: String?,
        plan: IPAIconPlan?,
        expectedPaths: Set<String>
    ) throws {
        var problems: [String] = []

        let archive: IPAArchive
        do {
            archive = try IPAArchive(url: url)
        } catch {
            throw IPAError.exportFailed("The exported IPA could not be reopened.")
        }

        if archive.info.bundleIdentifier != expectedBundleIdentifier {
            problems.append("Bundle ID was not written correctly.")
        }

        if let expectedVersion, archive.info.marketingVersion != expectedVersion {
            problems.append("Marketing version was not written correctly.")
        }

        if let expectedBuild, archive.info.buildNumber != expectedBuild {
            problems.append("Build number was not written correctly.")
        }

        if !archive.info.executable.isEmpty,
           let executable = archive.entry(at: archive.info.executablePath) {
            if executable.uncompressedSize == 0 {
                problems.append("The app executable is empty.")
            }
        } else if !archive.info.executable.isEmpty {
            problems.append("The app executable is missing.")
        }

        let paths = Set(archive.entries.map(\.path))
        let missing = expectedPaths.subtracting(paths)

        if !missing.isEmpty {
            problems.append("\(missing.count) archive entries are missing.")
        }

        if let plan {
            for slot in plan.slots {
                guard let data = try? archive.data(at: slot.path),
                      let metadata = PNGMetadata(data: data),
                      metadata.isComplete else {
                    problems.append("Icon \(slot.path) is missing or invalid.")
                    continue
                }

                if metadata.width != slot.pixelWidth || metadata.height != slot.pixelHeight {
                    problems.append("Icon \(slot.path) has the wrong size.")
                }
            }
        }

        if !problems.isEmpty {
            throw IPAError.validationFailed(problems)
        }
    }
}
