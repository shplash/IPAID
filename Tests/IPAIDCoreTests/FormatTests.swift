import XCTest
@testable import IPAIDCore

final class FormatTests: XCTestCase {

    func testPNGMetadataReadsDimensions() throws {
        let data = Fixtures.pngData(width: 120, height: 120)
        let metadata = try XCTUnwrap(PNGMetadata(data: data))

        XCTAssertEqual(metadata.width, 120)
        XCTAssertEqual(metadata.height, 120)
        XCTAssertTrue(metadata.isSquare)
        XCTAssertTrue(metadata.hasAlphaChannel)
        XCTAssertTrue(metadata.isComplete)
    }

    func testPNGMetadataRejectsInvalidData() {
        XCTAssertNil(PNGMetadata(data: Data("nope".utf8)))
        XCTAssertNil(PNGMetadata(data: Fixtures.pngData(width: 0, height: 0)))
    }

    func testPNGDetectsTruncatedImage() throws {
        let data = Fixtures.pngData(width: 60, height: 60)
        let truncated = data.prefix(40)
        let metadata = try XCTUnwrap(PNGMetadata(data: Data(truncated)))

        XCTAssertFalse(metadata.isComplete)
    }

    func testIconSizeFromNames() {
        XCTAssertEqual(IPAIconPlan.sizeFromName("AppIcon60x60@2x"), 120)
        XCTAssertEqual(IPAIconPlan.sizeFromName("AppIcon60x60@3x"), 180)
        XCTAssertEqual(IPAIconPlan.sizeFromName("AppIcon83.5x83.5@2x~ipad"), 167)
        XCTAssertEqual(IPAIconPlan.sizeFromName("Icon-60@2x"), 120)
        XCTAssertNil(IPAIconPlan.sizeFromName("Icon"))
    }

    func testThinMachOArchitectures() {
        let arm64 = Fixtures.machO(architectures: [(0x0100000C, 0)])
        XCTAssertEqual(MachOArchitectures.parse(data: arm64), ["arm64"])

        let arm64e = Fixtures.machO(architectures: [(0x0100000C, 2)])
        XCTAssertEqual(MachOArchitectures.parse(data: arm64e), ["arm64e"])

        let armv7 = Fixtures.machO(architectures: [(12, 9)])
        XCTAssertEqual(MachOArchitectures.parse(data: armv7), ["armv7s"])
    }

    func testFatMachOArchitectures() {
        let fat = Fixtures.machO(architectures: [(0x0100000C, 0), (12, 9)])
        XCTAssertEqual(MachOArchitectures.parse(data: fat), ["arm64", "armv7s"])
    }

    func testMachOIgnoresInvalidData() {
        XCTAssertTrue(MachOArchitectures.parse(data: Data("random".utf8)).isEmpty)
    }

    func testPlistValueRoundTrip() throws {
        let dictionary: [String: Any] = [
            "String": "value",
            "Boolean": true,
            "Integer": 42,
            "Real": 1.5,
            "Nested": [
                "Array": [1, 2, 3],
                "Dictionary": ["Key": "Value"]
            ]
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .xml,
            options: 0
        )
        let parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let map = try XCTUnwrap(parsed as? [String: Any])

        let boolean = try XCTUnwrap(PlistValue(any: map["Boolean"]!))
        XCTAssertEqual(boolean, .bool(true))

        let integer = try XCTUnwrap(PlistValue(any: map["Integer"]!))
        XCTAssertEqual(integer, .integer(42))

        let real = try XCTUnwrap(PlistValue(any: map["Real"]!))
        XCTAssertEqual(real, .real(1.5))

        let string = try XCTUnwrap(PlistValue(any: map["String"]!))
        XCTAssertEqual(string, .string("value"))

        let nested = try XCTUnwrap(PlistValue(any: map["Nested"]!))
        guard case let .dictionary(values) = nested else {
            return XCTFail("Expected a dictionary")
        }
        XCTAssertEqual(values["Array"], .array([.integer(1), .integer(2), .integer(3)]))
    }

    func testOverridesApplyAndPreserveUnknownKeys() {
        var dictionary: [String: Any] = [
            "CFBundleIdentifier": "com.example.app",
            "Unknown": "keep",
            "RemoveMe": "value"
        ]

        var overrides = InfoPlistOverrides()
        overrides.set(.string("new"), for: "Added")
        overrides.set(.bool(true), for: "Enabled")
        overrides.remove("RemoveMe")
        overrides.apply(to: &dictionary)

        XCTAssertEqual(dictionary["CFBundleIdentifier"] as? String, "com.example.app")
        XCTAssertEqual(dictionary["Unknown"] as? String, "keep")
        XCTAssertEqual(dictionary["Added"] as? String, "new")
        XCTAssertEqual(dictionary["Enabled"] as? Bool, true)
        XCTAssertNil(dictionary["RemoveMe"])
    }

    func testProtectedKeys() {
        XCTAssertTrue(ProtectedPlistKeys.isProtected("CFBundleIdentifier"))
        XCTAssertTrue(ProtectedPlistKeys.isProtected("CFBundleIcons~ipad"))
        XCTAssertTrue(ProtectedPlistKeys.isProtected("CFBundleVersion"))
        XCTAssertFalse(ProtectedPlistKeys.isProtected("MinimumOSVersion"))
    }

    func testSerializationPreservesFormat() throws {
        let dictionary: [String: Any] = ["Key": "Value"]
        let binary = try PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .binary,
            options: 0
        )

        XCTAssertEqual(IPAArchive.plistFormat(of: binary), .binary)

        let roundTrip = try IPAArchive.serialize(dictionary, format: .binary)
        XCTAssertEqual(IPAArchive.plistFormat(of: roundTrip), .binary)
    }

    func testExportFileNameUsesTheDefaultSuffix() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "Example.ipa", suffix: "-ipaid"),
            "Example-ipaid.ipa"
        )
    }

    func testExportFileNameWithoutASuffix() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "Example.ipa", suffix: ""),
            "Example.ipa"
        )
    }

    func testExportFileNameWithACustomSuffix() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "Example.ipa", suffix: "-edited"),
            "Example-edited.ipa"
        )
    }

    func testExportFileNameDoesNotRepeatTheSuffix() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "Example-ipaid.ipa", suffix: "-ipaid"),
            "Example-ipaid.ipa"
        )
    }

    func testExportFileNameStripsTheSourceExtension() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "My App.v2.ipa", suffix: "-x"),
            "My App.v2-x.ipa"
        )
    }

    func testExportFileNameFallsBackForAMissingName() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "", suffix: "-ipaid"),
            "IPA-ipaid.ipa"
        )
    }

    func testExportFileNameSanitisesTheSuffix() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "Example.ipa", suffix: "/bad:name"),
            "Examplebadname.ipa"
        )
    }

    func testExportFileNameTrimsWhitespace() {
        XCTAssertEqual(
            IPAFormatting.exportFileName(originalFileName: "Example.ipa", suffix: "  -trim  "),
            "Example-trim.ipa"
        )
    }

    func testDeviceFamiliesMapToNames() {
        XCTAssertEqual(
            IPABundleParsing.deviceFamilies(from: ["UIDeviceFamily": [1, 2]]),
            ["iPhone", "iPad"]
        )
        XCTAssertEqual(
            IPABundleParsing.deviceFamilies(from: ["UIDeviceFamily": [1]]),
            ["iPhone"]
        )
        XCTAssertEqual(
            IPABundleParsing.deviceFamilies(from: ["UIDeviceFamily": [9]]),
            ["family 9"]
        )
        XCTAssertTrue(IPABundleParsing.deviceFamilies(from: [:]).isEmpty)
    }

    func testTargetSDKFallsBackThroughKnownKeys() {
        XCTAssertEqual(IPABundleParsing.targetSDK(from: ["DTSDKName": "iphoneos18.0"]), "iphoneos18.0")
        XCTAssertEqual(IPABundleParsing.targetSDK(from: ["DTPlatformVersion": "18.0"]), "18.0")
        XCTAssertEqual(IPABundleParsing.targetSDK(from: [:]), "")
    }
}
