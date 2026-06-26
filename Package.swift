// swift-tools-version: 6.3.1

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
        // Root: namespace + foundational, stdlib-only declarations (zero deps).
        .library(
            name: "List Primitive",
            targets: ["List Primitive"]
        ),
        // Sub-namespace: List.Index typed-index surface (needs Index Primitives).
        .library(
            name: "List Index Primitives",
            targets: ["List Index Primitives"]
        ),
        // Umbrella: re-exports the root + all sub-namespaces.
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
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
    ],
    targets: [
        // MARK: - Root
        // Root: the `enum List` namespace shell + foundational stdlib-only decls.
        // Zero external deps per [MOD-017]. Future zero-dep List disciplines
        // live here; the linked-list discipline was extracted to
        // swift-list-linked-primitives.
        .target(
            name: "List Primitive",
            dependencies: []
        ),

        // MARK: - Sub-namespaces
        // Index: the `List.Index` typed-index surface over Index_Primitives.
        .target(
            name: "List Index Primitives",
            dependencies: [
                "List Primitive",
                .product(name: "Index Primitives", package: "swift-index-primitives"),
            ]
        ),

        // MARK: - Umbrella
        // Umbrella: re-exports the root + all sub-namespaces.
        .target(
            name: "List Primitives",
            dependencies: [
                "List Primitive",
                "List Index Primitives",
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "List Primitives Test Support",
            dependencies: [
                "List Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "List Primitives Tests",
            dependencies: [
                "List Primitives",
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
