// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-list-primitives",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [

        .library(
            name: "List Primitive",
            targets: ["List Primitive"]
        ),

        .library(
            name: "List Index Primitives",
            targets: ["List Index Primitives"]
        ),

        .library(
            name: "List Primitives",
            targets: ["List Primitives"]
        ),
        .library(
            name: "List Primitives Test Support",
            targets: ["List Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-primitives/swift-index-primitives.git",
            branch: "main"
        )
    ],
    targets: [

        .target(
            name: "List Primitive",
            dependencies: []
        ),

        .target(
            name: "List Index Primitives",
            dependencies: [
                "List Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        .target(
            name: "List Primitives",
            dependencies: [
                "List Primitive",
                "List Index Primitives",
            ]
        ),

        .target(
            name: "List Primitives Test Support",
            dependencies: [
                "List Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),

        .testTarget(
            name: "List Primitives Tests",
            dependencies: [
                "List Primitives"
            ]
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

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout")
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
