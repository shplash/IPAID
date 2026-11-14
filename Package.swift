// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "IPAIDCore",
    platforms: [
        .macOS(.v11),
        .iOS(.v14)
    ],
    products: [
        .library(name: "IPAIDCore", targets: ["IPAIDCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19")
    ],
    targets: [
        .target(
            name: "IPAIDCore",
            dependencies: ["ZIPFoundation"],
            path: "App/Core"
        ),
        .testTarget(
            name: "IPAIDCoreTests",
            dependencies: ["IPAIDCore"],
            path: "Tests/IPAIDCoreTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
