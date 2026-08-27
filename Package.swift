// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-pool",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Pool",
            targets: ["Pool"]
        ),
        .library(
            name: "Pool Standard Library Integration",
            targets: ["Pool Standard Library Integration"]
        ),
        .library(
            name: "Pool Apple Foundation Integration",
            targets: ["Pool Apple Foundation Integration"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-atoms/swift-dimension.git",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "Pool",
            dependencies: [
                .product(name: "Dimension", package: "swift-dimension")
            ]
        ),
        .target(
            name: "Pool Standard Library Integration",
            dependencies: ["Pool"]
        ),
        .target(
            name: "Pool Apple Foundation Integration",
            dependencies: [
                "Pool",
                "Pool Standard Library Integration",
            ]
        ),
        .testTarget(
            name: "Pool Tests",
            dependencies: ["Pool"],
            path: "Tests/Pool Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
