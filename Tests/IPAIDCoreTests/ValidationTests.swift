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

    func testEmptyFieldsShareTheCannotBeEmptyMessage() {
        XCTAssertEqual(MetadataValidation.cannotBeEmpty, "Cannot be empty")
        XCTAssertFalse(MetadataValidation.displayName("").isEmpty)
        XCTAssertFalse(MetadataValidation.displayName("   ").isEmpty)
        XCTAssertFalse(MetadataValidation.bundleIdentifier("").isEmpty)
        XCTAssertFalse(MetadataValidation.bundleIdentifier("  ").isEmpty)
    }

    func testFilledFieldsReportNoCannotBeEmptyMessage() {
        XCTAssertEqual(MetadataValidation.displayName("Example"), "")
        XCTAssertEqual(MetadataValidation.bundleIdentifier("com.example.app"), "")
    }

    func testBuildAndVersionLabels() {
        XCTAssertEqual(IPAFormatting.buildLabel("112"), "b112")
        XCTAssertEqual(IPAFormatting.buildLabel(" 7 "), "b7")
        XCTAssertEqual(IPAFormatting.buildLabel(""), "")
        XCTAssertEqual(IPAFormatting.versionLabel("1.21"), "v1.21")
        XCTAssertEqual(IPAFormatting.versionLabel(""), "")
    }

    func testExtensionBulkTitleFollowsTheSelection() {
        let available = ["A", "B", "C"]

        XCTAssertEqual(
            ExtensionSelection.bulkTitle(available: available, removed: []),
            "Disable All"
        )
        XCTAssertEqual(
            ExtensionSelection.bulkTitle(available: available, removed: ["B"]),
            "Enable All"
        )
    }

    func testExtensionBulkSelectionTogglesEverything() {
        let available = ["A", "B", "C"]

        XCTAssertEqual(
            ExtensionSelection.bulkSelection(available: available, removed: []),
            Set(available)
        )
        XCTAssertEqual(
            ExtensionSelection.bulkSelection(available: available, removed: ["B"]),
            Set<String>()
        )
        XCTAssertEqual(
            ExtensionSelection.bulkSelection(available: available, removed: ["A", "B", "C"]),
            Set<String>()
        )
    }

    func testExtensionBulkSelectionRoundTrips() {
        let available = ["A", "B", "C"]

        let disabled = ExtensionSelection.bulkSelection(available: available, removed: [])
        XCTAssertFalse(ExtensionSelection.allEnabled(available: available, removed: disabled))
        XCTAssertEqual(ExtensionSelection.keptCount(available: available, removed: disabled), 0)

        let enabled = ExtensionSelection.bulkSelection(available: available, removed: disabled)
        XCTAssertTrue(ExtensionSelection.allEnabled(available: available, removed: enabled))
        XCTAssertEqual(ExtensionSelection.keptCount(available: available, removed: enabled), 3)
    }

    func testExtensionBulkHandlesAnEmptyList() {
        XCTAssertTrue(ExtensionSelection.allEnabled(available: [], removed: []))
        XCTAssertEqual(ExtensionSelection.bulkTitle(available: [], removed: []), "Disable All")
        XCTAssertEqual(ExtensionSelection.bulkSelection(available: [], removed: []), Set<String>())
    }
}
