import XCTest
@testable import IPAIDCore

final class ValidationTests: XCTestCase {

    func testBundleIdentifierRules() {
        XCTAssertEqual(MetadataValidation.bundleIdentifier("com.example.app"), "")
        XCTAssertEqual(MetadataValidation.bundleIdentifier(" com.example.app "), "")
        XCTAssertFalse(MetadataValidation.bundleIdentifier("").isEmpty)
        XCTAssertFalse(MetadataValidation.bundleIdentifier("nodots").isEmpty)
        XCTAssertFalse(MetadataValidation.bundleIdentifier("com..app").isEmpty)
        XCTAssertFalse(MetadataValidation.bundleIdentifier(".com.app").isEmpty)
        XCTAssertFalse(MetadataValidation.bundleIdentifier("com.app.").isEmpty)
        XCTAssertFalse(MetadataValidation.bundleIdentifier("com.exa mple").isEmpty)
    }

    func testMarketingVersionRules() {
        XCTAssertEqual(MetadataValidation.marketingVersion("1.21"), "")
        XCTAssertEqual(MetadataValidation.marketingVersion("2.0.1"), "")
        XCTAssertFalse(MetadataValidation.marketingVersion("").isEmpty)
        XCTAssertFalse(MetadataValidation.marketingVersion("1.2.3.4").isEmpty)
        XCTAssertFalse(MetadataValidation.marketingVersion("v1.2").isEmpty)
        XCTAssertFalse(MetadataValidation.marketingVersion("1.").isEmpty)
    }

    func testBuildNumberRules() {
        XCTAssertEqual(MetadataValidation.buildNumber("112"), "")
        XCTAssertEqual(MetadataValidation.buildNumber("1.0.1"), "")
        XCTAssertFalse(MetadataValidation.buildNumber("").isEmpty)
        XCTAssertFalse(MetadataValidation.buildNumber("abc").isEmpty)
        XCTAssertFalse(MetadataValidation.buildNumber("1.2.3.4").isEmpty)
    }

    func testURLSchemeRules() {
        XCTAssertEqual(MetadataValidation.urlScheme("myapp", allowEmpty: false), "")
        XCTAssertEqual(MetadataValidation.urlScheme("", allowEmpty: true), "")
        XCTAssertFalse(MetadataValidation.urlScheme("", allowEmpty: false).isEmpty)
        XCTAssertFalse(MetadataValidation.urlScheme("1app", allowEmpty: false).isEmpty)
        XCTAssertFalse(MetadataValidation.urlScheme("my app", allowEmpty: false).isEmpty)
    }

    func testDisplayNameRules() {
        XCTAssertEqual(MetadataValidation.displayName("Example"), "")
        XCTAssertFalse(MetadataValidation.displayName("").isEmpty)
        XCTAssertFalse(MetadataValidation.displayName(String(repeating: "a", count: 31)).isEmpty)
    }
}
