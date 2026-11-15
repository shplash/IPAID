import XCTest
@testable import IPAIDCore

final class TextFileEditingTests: XCTestCase {

    func testCommonTextFormatsAreEditable() {
        XCTAssertTrue(TextFileEditing.isEditablePath("Payload/App.app/data.json"))
        XCTAssertTrue(TextFileEditing.isEditablePath("Payload/App.app/strings/en.strings"))
        XCTAssertTrue(TextFileEditing.isEditablePath("Payload/App.app/readme.txt"))
        XCTAssertTrue(TextFileEditing.isEditablePath("Payload/App.app/config.yaml"))
        XCTAssertTrue(TextFileEditing.isEditablePath("Payload/App.app/App.entitlements"))
        XCTAssertTrue(TextFileEditing.isEditablePath("Payload/App.app/Settings.bundle/Root.plist"))
    }

    func testBinaryFormatsAreNotEditable() {
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/App"))
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/icon.png"))
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/Assets.car"))
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/lib.dylib"))
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/archive.zip"))
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/audio.m4a"))
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/"))
    }

    func testInfoPlistIsExcludedAtEveryLocation() {
        XCTAssertTrue(TextFileEditing.isInfoPlist("Payload/App.app/Info.plist"))
        XCTAssertTrue(TextFileEditing.isInfoPlist("Payload/App.app/PlugIns/Widget.appex/Info.plist"))
        XCTAssertTrue(
            TextFileEditing.isInfoPlist("Payload/App.app/Frameworks/X.framework/Info.plist")
        )
        XCTAssertTrue(TextFileEditing.isInfoPlist("Payload/App.app/Settings.bundle/INFO.PLIST"))
        XCTAssertFalse(TextFileEditing.isInfoPlist("Payload/App.app/Settings.bundle/Root.plist"))

        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/Info.plist"))
        XCTAssertFalse(
            TextFileEditing.isEditablePath("Payload/App.app/Frameworks/X.framework/Info.plist")
        )
        XCTAssertFalse(TextFileEditing.isEditablePath("Payload/App.app/Settings.bundle/INFO.PLIST"))
    }

    func testPlainTextDecodes() {
        XCTAssertEqual(TextFileEditing.decode(Data("hello".utf8)), "hello")
    }

    func testBinaryDataIsRejected() {
        XCTAssertNil(TextFileEditing.decode(Data([0x00, 0x01, 0x02])))
        XCTAssertNil(TextFileEditing.decode(Data()))
        XCTAssertNil(TextFileEditing.decode(Data([0xFF, 0xFE, 0x00])))
    }

    func testInvalidUTF8IsRejected() {
        XCTAssertNil(TextFileEditing.decode(Data([0xC3, 0x28])))
    }

    func testBinaryPlistIsRejectedAsText() throws {
        let binary = try PropertyListSerialization.data(
            fromPropertyList: ["Key": "Value"],
            format: .binary,
            options: 0
        )

        XCTAssertNil(TextFileEditing.decode(binary))
    }

    func testOversizedFilesAreNotDecoded() {
        let data = Data(repeating: 0x41, count: TextFileEditing.maximumEditableSize + 1)
        XCTAssertNil(TextFileEditing.decode(data))
    }

    func testRoundTripPreservesContent() throws {
        let original = "{\n  \"key\": \"value\"\n}\n"
        let data = try XCTUnwrap(TextFileEditing.encode(original))

        XCTAssertEqual(TextFileEditing.decode(data), original)
    }

    func testOversizedTextIsNotEncoded() {
        let text = String(repeating: "a", count: TextFileEditing.maximumEditableSize + 1)
        XCTAssertNil(TextFileEditing.encode(text))
    }

    func testEditedFilesAreWrittenOnExport() throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let source = directory.appendingPathComponent("Example.ipa")
        try Fixtures.makeIPA(at: source)

        let archive = try IPAArchive(url: source)
        let target = "Payload/Example.app/en.lproj/Localizable.strings"
        let replacement = Data("\"hello\" = \"Edited\";".utf8)

        XCTAssertTrue(TextFileEditing.isEditablePath(target))

        var modifications = Fixtures.modifications(for: archive.info)
        modifications.editedFiles[target] = replacement

        XCTAssertTrue(modifications.hasChanges(from: archive.info))

        let output = directory.appendingPathComponent("Edited.ipa")
        _ = try IPAExporter.export(
            IPAExportRequest(sourceURL: source, outputURL: output, modifications: modifications)
        )

        let exported = try IPAArchive(url: output)
        XCTAssertEqual(try exported.data(at: target), replacement)

        XCTAssertNotEqual(try archive.data(at: target), replacement)
    }
}
