// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Cachyr",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(
            name: "Cachyr",
            targets: ["Cachyr"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Cachyr",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "CachyrTests",
            dependencies: ["Cachyr"]),
    ],
    swiftLanguageVersions: [.v5]
)
