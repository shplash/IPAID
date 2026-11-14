import XCTest
import ZIPFoundation
@testable import IPAIDCore

final class IPAExporterTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.temporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testExportAppliesIdentityAndVersionChanges() throws {
        let app = TestApp()
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(app, at: source)
        let sourceData = try Data(contentsOf: source)

        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info, app: app)
        modifications.bundleIdentifier = "com.example.clone"
        modifications.displayName = "Clone"
        modifications.marketingVersion = "2.0"
        modifications.buildNumber = "200"
        modifications.urlScheme = "clone"
        modifications.icon = IPAIconReplacement(
            imageName: "icon.png",
            previewData: Data(),
            files: Fixtures.iconFiles(for: archive.info.iconPlan)
        )

        let output = directory.appendingPathComponent("Example-clone.ipa")
        let result = try IPAExporter.export(
            IPAExportRequest(sourceURL: source, outputURL: output, modifications: modifications)
        )

        XCTAssertEqual(result.entryCount, archive.entries.count)
        XCTAssertGreaterThan(result.fileSize, 0)

        let exported = try IPAArchive(url: output)
        XCTAssertEqual(exported.info.bundleIdentifier, "com.example.clone")
        XCTAssertEqual(exported.info.displayName, "Clone")
        XCTAssertEqual(exported.info.bundleName, "Clone")
        XCTAssertEqual(exported.info.marketingVersion, "2.0")
        XCTAssertEqual(exported.info.buildNumber, "200")
        XCTAssertEqual(exported.info.urlScheme, "clone")
        XCTAssertEqual(exported.info.extensions.first?.bundleIdentifier, "com.example.clone.widget")
        XCTAssertEqual(exported.infoPlist["CFBundleIconFiles"] as? [String], archive.info.iconPlan.iPhoneBaseNames)

        for slot in archive.info.iconPlan.slots {
            let data = try exported.data(at: slot.path)
            let metadata = try XCTUnwrap(PNGMetadata(data: data))
            XCTAssertEqual(metadata.width, slot.pixelWidth)
            XCTAssertEqual(metadata.height, slot.pixelHeight)
        }

        let urlTypes = exported.infoPlist["CFBundleURLTypes"] as? [[String: Any]]
        XCTAssertEqual(urlTypes?.first?["CFBundleURLName"] as? String, "com.example.clone")

        XCTAssertTrue(exported.entries.contains { $0.path == "Payload/Example.app/en.lproj/Localizable.strings" })
        XCTAssertEqual(
            exported.entries.first { $0.path == "Payload/Example.app/Frameworks/Current" }?.kind,
            .symlink
        )

        let executable = exported.entries.first { $0.path == "Payload/Example.app/Example" }
        XCTAssertEqual(executable?.permissions, 0o755)

        let directoryEntry = exported.entries.first { $0.path == "Payload/Example.app/" }
        XCTAssertEqual(directoryEntry?.kind, .directory)
        XCTAssertEqual(directoryEntry?.permissions, 0o755)

        XCTAssertEqual(try Data(contentsOf: source), sourceData)
        XCTAssertEqual(try IPAArchive(url: source).info.bundleIdentifier, "com.example.app")
    }

    func testExportKeepsPlistFormat() throws {
        let source = directory.appendingPathComponent("Binary.ipa")
        try Fixtures.makeIPA(at: source)

        let binarySource = directory.appendingPathComponent("BinaryPlist.ipa")
        let archive = try IPAArchive(url: source)
        let binary = try PropertyListSerialization.data(
            fromPropertyList: archive.infoPlist,
            format: .binary,
            options: 0
        )

        try replaceEntry(
            in: source,
            path: archive.info.infoPlistPath,
            data: binary,
            destination: binarySource
        )

        let binaryArchive = try IPAArchive(url: binarySource)
        XCTAssertEqual(binaryArchive.infoPlistFormat, .binary)

        var modifications = Fixtures.modifications(for: binaryArchive.info)
        modifications.marketingVersion = "3.0"

        let output = directory.appendingPathComponent("Binary-out.ipa")
        _ = try IPAExporter.export(
            IPAExportRequest(sourceURL: binarySource, outputURL: output, modifications: modifications)
        )

        let exported = try IPAArchive(url: output)
        XCTAssertEqual(exported.infoPlistFormat, .binary)
        XCTAssertEqual(exported.info.marketingVersion, "3.0")
    }

    func testExportAddsIconsForAssetCatalogOnlyApp() throws {
        var app = TestApp()
        app.iconFiles = nil
        app.iconName = "AppIcon"
        app.includesAssetCatalog = true

        let source = directory.appendingPathComponent("AssetOnly.ipa")
        try Fixtures.makeIPA(app, at: source)

        let archive = try IPAArchive(url: source)
        XCTAssertTrue(archive.info.iconPlan.usesAssetCatalog)
        XCTAssertFalse(archive.info.iconPlan.slots.isEmpty)
        XCTAssertTrue(archive.info.iconPlan.existingSlots.isEmpty)

        var modifications = Fixtures.modifications(for: archive.info, app: app)
        modifications.icon = IPAIconReplacement(
            imageName: "replacement.png",
            previewData: Data(),
            files: Fixtures.iconFiles(for: archive.info.iconPlan)
        )

        let output = directory.appendingPathComponent("AssetOnly-out.ipa")
        let result = try IPAExporter.export(
            IPAExportRequest(sourceURL: source, outputURL: output, modifications: modifications)
        )

        XCTAssertFalse(result.summary.addedFiles.isEmpty)

        let exported = try IPAArchive(url: output)
        XCTAssertNil(exported.infoPlist["CFBundleIconName"])
        XCTAssertEqual(exported.infoPlist["CFBundleIconFiles"] as? [String], exported.info.iconPlan.iPhoneBaseNames)

        for slot in archive.info.iconPlan.slots {
            let data = try exported.data(at: slot.path)
            let metadata = try XCTUnwrap(PNGMetadata(data: data))
            XCTAssertEqual(metadata.width, slot.pixelWidth)
            XCTAssertEqual(metadata.height, slot.pixelHeight)
        }
    }

    func testExportRemovesExtensionAndRewritesIdentifiers() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info)
        modifications.bundleIdentifier = "com.clone.app"
        modifications.removedExtensions = [archive.info.extensions[0].root]

        let output = directory.appendingPathComponent("Removed.ipa")
        _ = try IPAExporter.export(
            IPAExportRequest(sourceURL: source, outputURL: output, modifications: modifications)
        )

        let exported = try IPAArchive(url: output)
        XCTAssertTrue(exported.info.extensions.isEmpty)
        XCTAssertFalse(exported.entries.contains { $0.path.contains("Widget.appex") })
        XCTAssertEqual(exported.info.bundleIdentifier, "com.clone.app")
    }

    func testExportAppliesAdvancedOverrides() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info)
        modifications.plistOverrides.set(.array([.string("audio")]), for: "UIBackgroundModes")
        modifications.plistOverrides.set(.string("custom"), for: "CustomKey")
        modifications.plistOverrides.remove("MinimumOSVersion")

        let output = directory.appendingPathComponent("Overrides.ipa")
        _ = try IPAExporter.export(
            IPAExportRequest(sourceURL: source, outputURL: output, modifications: modifications)
        )

        let exported = try IPAArchive(url: output)
        XCTAssertEqual(exported.infoPlist["CustomKey"] as? String, "custom")
        XCTAssertEqual(exported.infoPlist["UIBackgroundModes"] as? [String], ["audio"])
        XCTAssertNil(exported.infoPlist["MinimumOSVersion"])
        XCTAssertEqual(exported.infoPlist["CFBundlePackageType"] as? String, "APPL")
    }

    func testExportRejectsNoChanges() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        let modifications = Fixtures.modifications(for: archive.info)

        XCTAssertThrowsError(
            try IPAExporter.export(
                IPAExportRequest(
                    sourceURL: source,
                    outputURL: directory.appendingPathComponent("NoChanges.ipa"),
                    modifications: modifications
                )
            )
        )
    }

    func testExportRejectsInvalidValues() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info)
        modifications.bundleIdentifier = "invalid"
        modifications.marketingVersion = "abc"

        let problems = modifications.problems(comparedTo: archive.info)
        XCTAssertTrue(problems.contains("Bundle ID must contain at least one dot."))
        XCTAssertTrue(problems.contains("Marketing version must use numbers separated by dots."))
    }

    func testExportRejectsProtectedPlistKeys() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info)
        modifications.plistOverrides.set(.string("x"), for: "CFBundleExecutable")

        let problems = modifications.problems(comparedTo: archive.info)
        XCTAssertTrue(problems.contains { $0.contains("managed by IPAID") })
    }

    func testExportRejectsOutputEqualToSource() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)
        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info)
        modifications.marketingVersion = "9.9"

        XCTAssertThrowsError(
            try IPAExporter.export(
                IPAExportRequest(sourceURL: source, outputURL: source, modifications: modifications)
            )
        )
    }

    func testSummaryListsOnlyRelevantChanges() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info)
        modifications.buildNumber = "43"

        let summary = IPAModificationSummary(
            info: archive.info,
            entries: archive.entries,
            modifications: modifications
        )

        XCTAssertEqual(summary.changes.count, 1)
        XCTAssertEqual(summary.changes[0].id, "buildNumber")
        XCTAssertEqual(summary.changes[0].original, "42")
        XCTAssertEqual(summary.changes[0].updated, "43")
        XCTAssertEqual(summary.modifiedFiles, [archive.info.infoPlistPath])
    }

    private func replaceEntry(
        in source: URL,
        path: String,
        data: Data,
        destination: URL
    ) throws {
        let input = try Archive(url: source, accessMode: .read)
        let output = try Archive(url: destination, accessMode: .create)

        for entry in input {
            let entryData: Data

            if entry.path == path {
                entryData = data
            } else {
                var buffer = Data()
                _ = try input.extract(entry) { buffer.append($0) }
                entryData = buffer
            }

            if entry.type == .directory {
                try output.addEntry(
                    with: entry.path,
                    type: .directory,
                    uncompressedSize: Int64(0),
                    provider: { (_: Int64, _: Int) in Data() }
                )
            } else {
                try output.addEntry(
                    with: entry.path,
                    type: .file,
                    uncompressedSize: Int64(entryData.count),
                    compressionMethod: .deflate,
                    provider: { (position: Int64, size: Int) in
                        let start = Int(position)
                        let end = min(start + size, entryData.count)
                        return start < end ? entryData.subdata(in: start..<end) : Data()
                    }
                )
            }
        }
    }
}
