import XCTest
@testable import IPAIDCore

final class IPAArchiveTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = try Fixtures.temporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testReadsBundleMetadata() throws {
        let url = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: url)

        let archive = try IPAArchive(url: url)
        let info = archive.info

        XCTAssertEqual(info.bundleIdentifier, "com.example.app")
        XCTAssertEqual(info.displayName, "Example")
        XCTAssertEqual(info.marketingVersion, "1.2")
        XCTAssertEqual(info.buildNumber, "42")
        XCTAssertEqual(info.minimumOSVersion, "14.0")
        XCTAssertEqual(info.executable, "Example")
        XCTAssertEqual(info.urlScheme, "example")
        XCTAssertEqual(info.appRoot, "Payload/Example.app/")
        XCTAssertEqual(info.infoPlistPath, "Payload/Example.app/Info.plist")
        XCTAssertEqual(info.architectures, ["arm64", "armv7s"])
        XCTAssertGreaterThan(info.fileSize, 0)

        XCTAssertEqual(info.extensions.count, 1)
        XCTAssertEqual(info.extensions[0].bundleIdentifier, "com.example.app.widget")
        XCTAssertEqual(info.extensions[0].root, "Payload/Example.app/PlugIns/Widget.appex/")

        XCTAssertEqual(info.iconPlan.slots.count, 2)
        XCTAssertFalse(info.iconPlan.usesAssetCatalog)
        XCTAssertEqual(
            info.iconPlan.slots.map(\.pixelWidth).sorted(),
            [120, 180]
        )
    }

    func testRejectsNonArchive() throws {
        let url = directory.appendingPathComponent("NotAnIPA.ipa")
        try Data("not an archive".utf8).write(to: url)

        XCTAssertThrowsError(try IPAArchive(url: url))
    }

    func testReadsEntryData() throws {
        let url = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: url)

        let archive = try IPAArchive(url: url)
        let strings = try archive.data(at: "Payload/Example.app/en.lproj/Localizable.strings")

        XCTAssertEqual(String(data: strings, encoding: .utf8), "\"hello\" = \"Hello\";")
    }

    func testPreservesSymlinkEntry() throws {
        let url = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: url)

        let archive = try IPAArchive(url: url)
        let symlink = archive.entries.first { $0.path == "Payload/Example.app/Frameworks/Current" }

        XCTAssertEqual(symlink?.kind, .symlink)
    }

    func testDetectsBundledVersionReferences() throws {
        let url = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: url)

        let archive = try IPAArchive(url: url)
        let references = IPAVersionReferenceScanner.scan(archive: archive)

        XCTAssertEqual(
            references.map(\.path),
            ["Payload/Example.app/Settings.bundle/Root.plist"]
        )
        XCTAssertEqual(references.first?.value, "1.2")
    }
}
