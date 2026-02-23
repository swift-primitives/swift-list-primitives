// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-list-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "List Primitives",
            targets: ["List Primitives"]
        ),
        .library(
            name: "List Primitives Core",
            targets: ["List Primitives Core"]
        ),
        .library(
            name: "List Linked Primitives",
            targets: ["List Linked Primitives"]
        ),
        .library(
            name: "List Primitives Test Support",
            targets: ["List Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-buffer-primitives"),
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-input-primitives"),
        .package(path: "../swift-collection-primitives"),
        .package(path: "../swift-property-primitives"),
    ],
    targets: [
        // Core: Namespace enums, type declarations, error types
        .target(
            name: "List Primitives Core",
            dependencies: [
                .product(name: "Buffer Linked Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Linked Inline Primitives", package: "swift-buffer-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Input Primitives", package: "swift-input-primitives"),
                .product(name: "Collection Primitives", package: "swift-collection-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Linked: Operations as extensions on types declared in Core
        .target(
            name: "List Linked Primitives",
            dependencies: [
                "List Primitives Core",
                .product(name: "Buffer Linked Inline Primitives", package: "swift-buffer-primitives"),
            ]
        ),
        // Umbrella: Re-exports Core + Linked
        .target(
            name: "List Primitives",
            dependencies: [
                "List Primitives Core",
                "List Linked Primitives",
            ]
        ),
        .target(
            name: "List Primitives Test Support",
            dependencies: [
                "List Primitives",
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "List Primitives Tests",
            dependencies: [
                "List Primitives",
                "List Primitives Test Support",
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
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
