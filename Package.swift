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
            name: "Pool Primitive",
            targets: ["Pool Primitive"]
        ),

        .library(
            name: "Pool Scope",
            targets: ["Pool Scope"]
        ),
        .library(
            name: "Pool ID",
            targets: ["Pool ID"]
        ),
        .library(
            name: "Pool Error",
            targets: ["Pool Error"]
        ),
        .library(
            name: "Pool Capacity",
            targets: ["Pool Capacity"]
        ),

        .library(
            name: "Pool Lifecycle",
            targets: ["Pool Lifecycle"]
        ),
        .library(
            name: "Pool Metrics",
            targets: ["Pool Metrics"]
        ),

        .library(
            name: "Pool Acquire",
            targets: ["Pool Acquire"]
        ),
        .library(
            name: "Pool Release",
            targets: ["Pool Release"]
        ),

        .library(
            name: "Pool Bounded",
            targets: ["Pool Bounded"]
        ),

        .library(
            name: "Pool",
            targets: ["Pool"]
        ),
        .library(
            name: "Pool Test Support",
            targets: ["Pool Test Support"]
        ),
    ],
    traits: [
        .default(enabledTraits: ["Concurrency"]),
        .trait(
            name: "Concurrency",
            description: "Enable asynchronous bounded resource pooling."
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-async.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-queue.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-stack.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-array.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-fixed.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-column.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-buffer-linear.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-ownership-shared.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-storage.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-atoms/swift-memory.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-memory-allocation.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-buffer.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-tagged-collection.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-dimension.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-ownership.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-effect.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-index.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-iterator.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-either.git",
            branch: "main"
        ),
    ],
    targets: [

        .target(
            name: "Pool Primitive",
            dependencies: []
        ),

        .target(
            name: "Pool Scope",
            dependencies: [
                "Pool Primitive",
                .product(name: "Dimension", package: "swift-dimension"),
                .product(name: "Async", package: "swift-async"),
            ]
        ),
        .target(
            name: "Pool ID",
            dependencies: [
                "Pool Primitive",
                "Pool Scope",
                .product(name: "Dimension", package: "swift-dimension"),
            ]
        ),
        .target(
            name: "Pool Error",
            dependencies: [
                "Pool Primitive",
                "Pool Scope",
                "Pool ID",
            ]
        ),
        .target(
            name: "Pool Capacity",
            dependencies: [
                "Pool Primitive",
                "Pool Error",
            ]
        ),

        .target(
            name: "Pool Lifecycle",
            dependencies: [
                "Pool Primitive",
                .product(name: "Async", package: "swift-async"),
            ]
        ),
        .target(
            name: "Pool Metrics",
            dependencies: [
                "Pool Primitive"
            ]
        ),

        .target(
            name: "Pool Acquire",
            dependencies: [
                "Pool Primitive",
                "Pool Scope",
                "Pool Error",
                .product(name: "Effect", package: "swift-effect"),
                .product(name: "Ownership", package: "swift-ownership"),
            ]
        ),
        .target(
            name: "Pool Release",
            dependencies: [
                "Pool Primitive",
                "Pool Scope",
                "Pool ID",
                .product(name: "Effect", package: "swift-effect"),
                .product(name: "Ownership", package: "swift-ownership"),
            ]
        ),

        .target(
            name: "Pool Bounded",
            dependencies: [
                .target(name: "Pool Primitive", condition: .when(traits: ["Concurrency"])),
                .target(name: "Pool Scope", condition: .when(traits: ["Concurrency"])),
                .target(name: "Pool ID", condition: .when(traits: ["Concurrency"])),
                .target(name: "Pool Error", condition: .when(traits: ["Concurrency"])),
                .target(
                    name: "Pool Capacity",
                    condition: .when(traits: ["Concurrency"])
                ),
                .target(
                    name: "Pool Lifecycle",
                    condition: .when(traits: ["Concurrency"])
                ),
                .target(name: "Pool Metrics", condition: .when(traits: ["Concurrency"])),
                .product(
                    name: "Column",
                    package: "swift-column",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Buffer Linear Bounded Primitive",
                    package: "swift-buffer-linear",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Buffer Linear Primitive",
                    package: "swift-buffer-linear",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Ownership Shared Primitive",
                    package: "swift-ownership-shared",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Storage Contiguous",
                    package: "swift-storage",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Memory",
                    package: "swift-memory",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Memory Allocator Primitive",
                    package: "swift-memory-allocation",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Buffer Primitive",
                    package: "swift-buffer",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Stack",
                    package: "swift-stack",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Array Primitive",
                    package: "swift-array",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Array",
                    package: "swift-array",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Fixed",
                    package: "swift-fixed",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Index",
                    package: "swift-index",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Iterable",
                    package: "swift-iterator",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Tagged Collection",
                    package: "swift-tagged-collection",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Async",
                    package: "swift-async",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Async Waiter",
                    package: "swift-async",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Async Mutex",
                    package: "swift-async",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Queue Primitive",
                    package: "swift-queue",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Queue",
                    package: "swift-queue",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Async Promise",
                    package: "swift-async",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Dimension",
                    package: "swift-dimension",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Ownership",
                    package: "swift-ownership",
                    condition: .when(traits: ["Concurrency"])
                ),
                .product(
                    name: "Either",
                    package: "swift-either",
                    condition: .when(traits: ["Concurrency"])
                ),
            ],
            swiftSettings: [
                .define("POOL_CONCURRENCY", .when(traits: ["Concurrency"]))
            ]
        ),

        .target(
            name: "Pool",
            dependencies: [
                "Pool Primitive",
                "Pool Scope",
                "Pool ID",
                "Pool Error",
                "Pool Capacity",
                "Pool Lifecycle",
                "Pool Metrics",
                "Pool Acquire",
                "Pool Release",
                .target(name: "Pool Bounded", condition: .when(traits: ["Concurrency"])),
            ],
            swiftSettings: [
                .define("POOL_CONCURRENCY", .when(traits: ["Concurrency"]))
            ]
        ),

        .target(
            name: "Pool Test Support",
            dependencies: [
                "Pool",
                .product(name: "Index Test Support", package: "swift-index"),
            ],
            path: "Tests/Support"
        ),

        .testTarget(
            name: "Pool Tests",
            dependencies: [
                "Pool",
                "Pool Test Support",
                .product(name: "Async", package: "swift-async"),
                .product(name: "Array", package: "swift-array"),
                .product(name: "Fixed", package: "swift-fixed"),
                .product(
                    name: "Tagged Collection",
                    package: "swift-tagged-collection"
                ),
            ],
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
