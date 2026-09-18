// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OffsideGolfCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "OffsideGolfCore", targets: ["OffsideGolfCore"])],
    targets: [
        .target(name: "OffsideGolfCore"),
        .testTarget(
            name: "OffsideGolfCoreTests",
            dependencies: ["OffsideGolfCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
