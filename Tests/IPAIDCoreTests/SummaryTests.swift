import XCTest
@testable import IPAIDCore

final class SummaryTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.temporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeArchive() throws -> IPAArchive {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)
        return try IPAArchive(url: source)
    }

    func testDisplayNameOnlyExportKeepsEveryOtherValue() throws {
        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        var modifications = Fixtures.modifications(for: archive.info)
        modifications.displayName = "Renamed"

        let output = directory.appendingPathComponent("Renamed.ipa")
        _ = try IPAExporter.export(
            IPAExportRequest(sourceURL: source, outputURL: output, modifications: modifications)
        )

        let exported = try IPAArchive(url: output)
        XCTAssertEqual(exported.info.displayName, "Renamed")
        XCTAssertEqual(exported.info.bundleName, "Renamed")
        XCTAssertEqual(exported.info.bundleIdentifier, "com.example.app")
        XCTAssertEqual(exported.info.marketingVersion, "1.2")
        XCTAssertEqual(exported.info.buildNumber, "42")
        XCTAssertEqual(exported.info.urlScheme, "example")
        XCTAssertEqual(exported.info.extensions.first?.bundleIdentifier, "com.example.app.widget")
    }

    func testDisplayNameSummaryTouchesOnlyTheMainPlist() throws {
        let archive = try makeArchive()

        var modifications = Fixtures.modifications(for: archive.info)
        modifications.displayName = "Renamed"

        let summary = IPAModificationSummary(
            info: archive.info,
            entries: archive.entries,
            modifications: modifications
        )

        XCTAssertEqual(summary.changes.map(\.id), ["displayName"])
        XCTAssertEqual(summary.modifiedFiles, [archive.info.infoPlistPath])
        XCTAssertTrue(summary.addedFiles.isEmpty)
        XCTAssertTrue(summary.removedFiles.isEmpty)
    }

    func testSummaryDoesNotClaimAddedIconsForExistingSlots() throws {
        let archive = try makeArchive()

        var modifications = Fixtures.modifications(for: archive.info)
        modifications.icon = IPAIconReplacement(
            imageName: "replacement.png",
            previewData: Data(),
            files: Fixtures.iconFiles(for: archive.info.iconPlan)
        )

        let summary = IPAModificationSummary(
            info: archive.info,
            entries: archive.entries,
            modifications: modifications
        )

        XCTAssertTrue(summary.addedFiles.isEmpty)
        XCTAssertEqual(summary.modifiedFiles.count, archive.info.iconPlan.existingSlots.count + 1)
    }

    func testSummaryLeavesTheSignatureWarningToThePreview() throws {
        let archive = try makeArchive()

        var modifications = Fixtures.modifications(for: archive.info)
        modifications.bundleIdentifier = "com.example.clone"

        let summary = IPAModificationSummary(
            info: archive.info,
            entries: archive.entries,
            modifications: modifications
        )

        XCTAssertFalse(summary.warnings.contains { $0.lowercased().contains("re-sign") })
    }

    func testExtensionRemovalIsListedInTheSummary() throws {
        let archive = try makeArchive()
        let root = archive.info.extensions[0].root

        var modifications = Fixtures.modifications(for: archive.info)
        modifications.removedExtensions = [root]

        let summary = IPAModificationSummary(
            info: archive.info,
            entries: archive.entries,
            modifications: modifications
        )

        XCTAssertFalse(summary.removedFiles.isEmpty)
        XCTAssertTrue(summary.removedFiles.allSatisfy { $0.hasPrefix(root) })
    }
}
