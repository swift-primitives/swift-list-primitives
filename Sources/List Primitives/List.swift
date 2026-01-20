// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

/// Namespace for linked list primitives.
///
/// `List` provides linked list types with configurable link counts per node.
/// The primary type is ``List/Linked`` with a generic parameter `N` controlling
/// the number of links per node:
///
/// - `List.Linked<1>`: Singly-linked list (forward link only)
/// - `List.Linked<2>`: Doubly-linked list (forward + backward links)
///
/// ## Example
///
/// ```swift
/// // Singly-linked list (O(1) prepend, O(n) append)
/// var singly = List<Int>.Linked<1>()
/// singly.prepend(1)
/// singly.popFirst()  // Optional(1)
///
/// // Doubly-linked list (O(1) prepend and append)
/// var doubly = List<Int>.Linked<2>()
/// doubly.append(1)
/// doubly.prepend(0)
/// doubly.popLast()   // Optional(1)
/// ```
///
/// ## Variants
///
/// Each variant supports both singly and doubly-linked configurations:
///
/// - ``List/Linked``: Dynamically-growing with amortized O(1) operations
/// - ``List/Linked/Bounded``: Fixed-capacity, throws on overflow
/// - ``List/Linked/Inline``: Zero-allocation inline storage with compile-time capacity
/// - ``List/Linked/Small``: Inline storage with automatic spill to heap
///
/// ## Arena-Based Storage
///
/// Unlike traditional linked lists using heap-allocated nodes, `List.Linked` uses
/// arena-based storage where all nodes are stored contiguously in a single allocation.
/// Nodes reference each other by index rather than pointer, improving cache locality
/// and reducing allocation overhead.
///
/// ## Move-Only Support
///
/// Both the list and its elements can be `~Copyable`:
///
/// ```swift
/// struct FileHandle: ~Copyable { ... }
/// var handles = List<FileHandle>.Linked<2>()
/// handles.prepend(FileHandle())
/// ```
///
/// ## Complexity by Link Count
///
/// | Operation | N=1 (Singly) | N=2 (Doubly) |
/// |-----------|--------------|--------------|
/// | prepend | O(1) | O(1) |
/// | append | O(n) | O(1) |
/// | popFirst | O(1) | O(1) |
/// | popLast | O(n) | O(1) |
public enum List<Element: ~Copyable> {}
