import Foundation
import XCTest
import ZIPFoundation
@testable import IPAIDCore

struct TestApp {
    var bundleIdentifier = "com.example.app"
    var displayName = "Example"
    var bundleName = "Example"
    var marketingVersion = "1.2"
    var buildNumber = "42"
    var executable = "Example"
    var minimumOSVersion = "14.0"
    var urlScheme = "example"
    var iconFiles: [String]? = ["AppIcon60x60"]
    var iconName: String?
    var includesAssetCatalog = false
    var includesExtension = true
    var includesSymlink = true

    func infoPlist() -> [String: Any] {
        var dictionary: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleDisplayName": displayName,
            "CFBundleName": bundleName,
            "CFBundleExecutable": executable,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": marketingVersion,
            "CFBundleVersion": buildNumber,
            "MinimumOSVersion": minimumOSVersion,
            "CFBundleURLTypes": [
                [
                    "CFBundleURLName": bundleIdentifier,
                    "CFBundleURLSchemes": [urlScheme]
                ]
            ],
            "UILaunchScreen": [String: Any]()
        ]

        if let iconFiles {
            dictionary["CFBundleIcons"] = [
                "CFBundlePrimaryIcon": [
                    "CFBundleIconFiles": iconFiles
                ]
            ]
            dictionary["CFBundleIconFiles"] = iconFiles
        }

        if let iconName {
            dictionary["CFBundleIconName"] = iconName
        }

        return dictionary
    }
}

enum Fixtures {

    static func pngData(width: Int, height: Int) -> Data {
        var data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])

        var header = Data()
        header.append(contentsOf: bigEndian(UInt32(width)))
        header.append(contentsOf: bigEndian(UInt32(height)))
        header.append(contentsOf: [8, 6, 0, 0, 0])
        data.append(chunk(type: "IHDR", payload: header))
        data.append(chunk(type: "IDAT", payload: Data([0x78, 0x9C, 0x03, 0x00, 0x00, 0x00, 0x00, 0x01])))
        data.append(chunk(type: "IEND", payload: Data()))

        return data
    }

    static func machO(architectures: [(UInt32, UInt32)]) -> Data {
        var data = Data()

        if architectures.count == 1 {
            data.append(contentsOf: bigEndian(UInt32(0xFEEDFACF)))
            data.append(contentsOf: bigEndian(architectures[0].0))
            data.append(contentsOf: bigEndian(architectures[0].1))
            data.append(contentsOf: [0, 0, 0, 0])
        } else {
            data.append(contentsOf: bigEndian(UInt32(0xCAFEBABE)))
            data.append(contentsOf: bigEndian(UInt32(architectures.count)))

            for (cpuType, cpuSubtype) in architectures {
                data.append(contentsOf: bigEndian(cpuType))
                data.append(contentsOf: bigEndian(cpuSubtype))
                data.append(contentsOf: bigEndian(UInt32(0)))
                data.append(contentsOf: bigEndian(UInt32(0)))
                data.append(contentsOf: bigEndian(UInt32(0)))
            }
        }

        return data
    }

    static func makeIPA(_ app: TestApp = TestApp(), at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let archive = try Archive(url: url, accessMode: .create)
        let plist = try PropertyListSerialization.data(
            fromPropertyList: app.infoPlist(),
            format: .xml,
            options: 0
        )

        try addDirectory(archive, "Payload/")
        try addDirectory(archive, "Payload/Example.app/")
        try add("Payload/Example.app/Info.plist", plist, to: archive)
        try add(
            "Payload/Example.app/Example",
            machO(architectures: [(0x0100000C, 0), (12, 9)]),
            to: archive,
            permissions: 0o755
        )

        try addDirectory(archive, "Payload/Example.app/en.lproj/")
        try add(
            "Payload/Example.app/en.lproj/Localizable.strings",
            Data("\"hello\" = \"Hello\";".utf8),
            to: archive
        )

        try addDirectory(archive, "Payload/Example.app/Settings.bundle/")
        let settingsPlist = try PropertyListSerialization.data(
            fromPropertyList: [
                "PreferenceSpecifiers": [
                    ["Title": "Version", "DefaultValue": app.marketingVersion]
                ]
            ] as [String: Any],
            format: .xml,
            options: 0
        )
        try add("Payload/Example.app/Settings.bundle/Root.plist", settingsPlist, to: archive)

        if app.iconFiles != nil {
            try add("Payload/Example.app/AppIcon60x60@2x.png", pngData(width: 120, height: 120), to: archive)
            try add("Payload/Example.app/AppIcon60x60@3x.png", pngData(width: 180, height: 180), to: archive)
        }

        if app.includesAssetCatalog {
            try add("Payload/Example.app/Assets.car", Data("car".utf8), to: archive)
        }

        try addDirectory(archive, "Payload/Example.app/Frameworks/")
        try addDirectory(archive, "Payload/Example.app/Frameworks/Example.framework/")
        let frameworkPlist = try PropertyListSerialization.data(
            fromPropertyList: [
                "CFBundleIdentifier": app.bundleIdentifier + ".framework",
                "CFBundleShortVersionString": app.marketingVersion
            ] as [String: Any],
            format: .xml,
            options: 0
        )
        try add(
            "Payload/Example.app/Frameworks/Example.framework/Info.plist",
            frameworkPlist,
            to: archive
        )
        try add(
            "Payload/Example.app/Frameworks/Example.framework/Example",
            machO(architectures: [(0x0100000C, 0)]),
            to: archive
        )

        if app.includesExtension {
            try addDirectory(archive, "Payload/Example.app/PlugIns/")
            try addDirectory(archive, "Payload/Example.app/PlugIns/Widget.appex/")

            let widgetPlist = try PropertyListSerialization.data(
                fromPropertyList: [
                    "CFBundleIdentifier": app.bundleIdentifier + ".widget",
                    "CFBundleDisplayName": "Example Widget",
                    "CFBundleExecutable": "Widget"
                ] as [String: Any],
                format: .xml,
                options: 0
            )

            try add("Payload/Example.app/PlugIns/Widget.appex/Info.plist", widgetPlist, to: archive)
            try add(
                "Payload/Example.app/PlugIns/Widget.appex/Widget",
                machO(architectures: [(0x0100000C, 0)]),
                to: archive
            )
        }

        if app.includesSymlink {
            try archive.addEntry(
                with: "Payload/Example.app/Frameworks/Current",
                type: .symlink,
                uncompressedSize: Int64("Example.framework".utf8.count),
                permissions: 0o777,
                provider: { (position: Int64, size: Int) in
                    let data = Data("Example.framework".utf8)
                    let start = Int(position)
                    let end = min(start + size, data.count)
                    return start < end ? data.subdata(in: start..<end) : Data()
                }
            )
        }
    }

    static func iconFiles(for plan: IPAIconPlan) -> [String: Data] {
        var files: [String: Data] = [:]

        for slot in plan.slots {
            files[slot.path] = pngData(width: slot.pixelWidth, height: slot.pixelHeight)
        }

        return files
    }

    static func temporaryDirectory(_ name: String = UUID().uuidString) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("IPAIDTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func modifications(
        for info: IPABundleInfo,
        app: TestApp = TestApp()
    ) -> IPAModifications {
        IPAModifications(
            bundleIdentifier: app.bundleIdentifier,
            displayName: app.displayName,
            marketingVersion: app.marketingVersion,
            buildNumber: app.buildNumber,
            urlScheme: app.urlScheme
        )
    }

    private static func add(
        _ path: String,
        _ data: Data,
        to archive: Archive,
        permissions: UInt16 = 0o644
    ) throws {
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            permissions: permissions,
            compressionMethod: .deflate,
            provider: { (position: Int64, size: Int) in
                let start = Int(position)
                let end = min(start + size, data.count)
                return start < end ? data.subdata(in: start..<end) : Data()
            }
        )
    }

    private static func addDirectory(_ archive: Archive, _ path: String) throws {
        try archive.addEntry(
            with: path,
            type: .directory,
            uncompressedSize: Int64(0),
            permissions: 0o755,
            provider: { (_: Int64, _: Int) in Data() }
        )
    }

    private static func chunk(type: String, payload: Data) -> Data {
        var data = Data()
        data.append(contentsOf: bigEndian(UInt32(payload.count)))
        data.append(Data(type.utf8))
        data.append(payload)
        data.append(contentsOf: bigEndian(UInt32(0)))
        return data
    }

    private static func bigEndian(_ value: UInt32) -> [UInt8] {
        [
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF)
        ]
    }
}
