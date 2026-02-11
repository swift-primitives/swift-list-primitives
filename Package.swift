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
        .testTarget(
            name: "List Primitives Tests",
            dependencies: ["List Primitives"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
