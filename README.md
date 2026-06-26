# List Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

List-discipline value types for Swift — the `List` namespace and a phantom-typed `List.Index` position that the package's list disciplines build on, with zero platform dependencies.

---

## Quick Start

`List<Element>` is an empty generic enum: the shared root namespace every list discipline in the package hangs off. Its first inhabitant is `List.Index`, a phantom-typed position whose element type is baked into the type. An index into a `List<Int>` and an index into a `List<String>` are *different types*, so crossing them is a compile error rather than a silent out-of-bounds bug.

```swift
import List_Primitives

// A position into a List<Int>. The element type travels inside the index type.
let head: List<Int>.Index = 0
let next: List<Int>.Index = 1

// Indices of distinct element types are distinct types: this would not compile.
//   let wrong: List<String>.Index = head   // ❌ type mismatch, caught at build time

print(head, next)
```

The `Element` parameter may be `~Copyable`, so the namespace and its index surface work uniformly for move-only element types as well as ordinary values.

The concrete linked-list discipline — `List.Linked` and its `Bounded`, `Inline`, and `Small` variants — lives in [`swift-list-linked-primitives`](https://github.com/swift-primitives/swift-list-linked-primitives). This package retains the namespace shell so every discipline shares one `List` root and one typed-index vocabulary.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-list-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "List Primitives", package: "swift-list-primitives"),
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux / Windows toolchain).

---

## Architecture

Three library products over a single dependency, `swift-index-primitives`. Import the umbrella `List Primitives` for everything, or a single sub-namespace target to narrow what you pull in.

| Product | Target | Purpose |
|---------|--------|---------|
| `List Primitive` | `Sources/List Primitive/` | The root `enum List<Element: ~Copyable>` namespace plus the package's foundational, stdlib-only declarations. Zero external dependencies. |
| `List Index Primitives` | `Sources/List Index Primitives/` | The `List.Index` typed-index surface, a `List<Element>` typealias for `Index<Element>` from `Index Primitives`. |
| `List Primitives` | `Sources/List Primitives/` | Umbrella: re-exports the root namespace and every sub-namespace. |
| `List Primitives Test Support` | `Tests/Support/` | Re-exports the umbrella and the index test-support surface for test consumers. |

Foundation-free.

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 26 | Full support |
| Linux | Full support |
| Windows | Full support |
| iOS / tvOS / watchOS / visionOS | Supported |

---

## Community

<!-- BEGIN: discussion -->
<!-- Discussion thread created at publication. -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
