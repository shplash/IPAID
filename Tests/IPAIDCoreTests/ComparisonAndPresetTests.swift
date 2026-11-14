import XCTest
@testable import IPAIDCore

final class ComparisonAndPresetTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.temporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testComparisonFindsMetadataAndFileChanges() throws {
        let source = directory.appendingPathComponent("Original.ipa")
        try Fixtures.makeIPA(at: source)
        let original = try IPAArchive(url: source)

        var modifications = Fixtures.modifications(for: original.info)
        modifications.marketingVersion = "2.0"
        modifications.buildNumber = "100"
        modifications.bundleIdentifier = "com.example.changed"

        let output = directory.appendingPathComponent("Changed.ipa")
        _ = try IPAExporter.export(
            IPAExportRequest(sourceURL: source, outputURL: output, modifications: modifications)
        )

        let changed = try IPAArchive(url: output)
        let result = IPAComparison.compare(
            left: original,
            leftName: "Original.ipa",
            right: changed,
            rightName: "Changed.ipa"
        )

        XCTAssertTrue(result.hasDifferences)
        XCTAssertEqual(result.differingMetadata.map(\.id), ["bundleIdentifier", "marketingVersion", "buildNumber", "extensionIDs"])
        XCTAssertTrue(result.changedFiles.contains(original.info.infoPlistPath))
        XCTAssertTrue(result.changedFiles.contains("Payload/Example.app/PlugIns/Widget.appex/Info.plist"))
        XCTAssertTrue(result.addedFiles.isEmpty)
        XCTAssertTrue(result.removedFiles.isEmpty)
    }

    func testComparisonOfIdenticalArchives() throws {
        let source = directory.appendingPathComponent("Original.ipa")
        try Fixtures.makeIPA(at: source)
        let copy = directory.appendingPathComponent("Copy.ipa")
        try FileManager.default.copyItem(at: source, to: copy)

        let left = try IPAArchive(url: source)
        let right = try IPAArchive(url: copy)
        let result = IPAComparison.compare(left: left, leftName: "A", right: right, rightName: "B")

        XCTAssertFalse(result.hasDifferences)
    }

    func testPresetRoundTrip() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "IPAIDTests-\(UUID().uuidString)"))
        let store = ExportPresetStore(defaults: defaults, key: "presets")

        let source = directory.appendingPathComponent("Preset.ipa")
        try Fixtures.makeIPA(at: source)
        let archive = try IPAArchive(url: source)

        var modifications = Fixtures.modifications(for: archive.info)
        modifications.bundleIdentifier = "com.reuse.app"
        modifications.displayName = "Reused"
        modifications.marketingVersion = "4.1"
        modifications.buildNumber = "410"
        modifications.urlScheme = "reused"
        modifications.removedExtensions = [archive.info.extensions[0].root]

        let presets = store.add(
            name: "Reuse",
            from: modifications,
            info: archive.info,
            availableExtensions: archive.info.extensions
        )

        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets[0].name, "Reuse")
        XCTAssertEqual(presets[0].removedExtensions, [archive.info.extensions[0].root])
        XCTAssertEqual(store.presets(), presets)

        var applied = IPAModifications(
            bundleIdentifier: "com.other.app",
            displayName: "Other",
            marketingVersion: "1.0",
            buildNumber: "1",
            urlScheme: "other"
        )

        presets[0].apply(to: &applied, availableExtensions: archive.info.extensions)
        XCTAssertEqual(applied.bundleIdentifier, "com.reuse.app")
        XCTAssertEqual(applied.displayName, "Reused")
        XCTAssertEqual(applied.removedExtensions, Set(archive.info.extensions.map(\.root)))

        let remaining = store.remove(presets[0])
        XCTAssertTrue(remaining.isEmpty)
    }

    func testPresetOnlyStoresChangedFields() throws {
        let source = directory.appendingPathComponent("Preset.ipa")
        try Fixtures.makeIPA(at: source)
        let archive = try IPAArchive(url: source)

        var modifications = Fixtures.modifications(for: archive.info)
        modifications.buildNumber = "43"

        let preset = ExportPreset.make(
            from: modifications,
            info: archive.info,
            name: "Build only",
            availableExtensions: archive.info.extensions
        )

        XCTAssertEqual(preset.buildNumber, "43")
        XCTAssertNil(preset.bundleIdentifier)
        XCTAssertNil(preset.displayName)
        XCTAssertNil(preset.marketingVersion)
        XCTAssertNil(preset.urlScheme)
        XCTAssertEqual(preset.fieldCount, 1)
    }

    func testPresetOnlyAppliesStoredFields() throws {
        let preset = ExportPreset(name: "Version only", marketingVersion: "9.9")

        var modifications = IPAModifications(
            bundleIdentifier: "com.example.app",
            displayName: "Example",
            marketingVersion: "1.2",
            buildNumber: "42",
            urlScheme: "example"
        )

        preset.apply(to: &modifications, availableExtensions: [])

        XCTAssertEqual(modifications.marketingVersion, "9.9")
        XCTAssertEqual(modifications.bundleIdentifier, "com.example.app")
        XCTAssertEqual(modifications.displayName, "Example")
        XCTAssertEqual(modifications.buildNumber, "42")
        XCTAssertEqual(modifications.urlScheme, "example")
    }

    func testPresetDropsUnavailableExtensions() throws {
        let preset = ExportPreset(
            name: "Old",
            removedExtensions: ["Payload/Other.app/PlugIns/Missing.appex/"]
        )

        var modifications = IPAModifications(
            bundleIdentifier: "com.example.app",
            displayName: "Example",
            marketingVersion: "1.2",
            buildNumber: "42",
            urlScheme: "example"
        )

        preset.apply(to: &modifications, availableExtensions: [])
        XCTAssertTrue(modifications.removedExtensions.isEmpty)
    }

    func testSessionKeepsOriginalCopy() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)
        let sourceData = try Data(contentsOf: source)

        let session = try IPASession(directory: directory.appendingPathComponent("Session"))
        let imported = try session.importIPA(from: source)

        XCTAssertEqual(try Data(contentsOf: imported), sourceData)

        let first = try session.outputURL(for: "Example.ipa")
        try Data("first".utf8).write(to: first)
        let second = try session.outputURL(for: "Example.ipa")

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: imported), sourceData)

        session.clean()
        XCTAssertFalse(FileManager.default.fileExists(atPath: imported.path))
    }
}
