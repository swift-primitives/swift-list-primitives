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

public import Index_Primitives

extension List where Element: ~Copyable {
    /// Type-safe index for list elements.
    ///
    /// Uses `Index<Element>` to provide compile-time safety preventing
    /// cross-collection index confusion.
    ///
    /// ## Position Semantics
    ///
    /// Position 0 is the head of the list (first element).
    /// Position `count - 1` is the tail (last element).
    ///
    /// ## Note on Access
    ///
    /// Linked lists do not support O(1) indexed access. Use iteration methods
    /// like `forEach` or `first`/`last` properties for element access.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let listIdx: List<Int>.Index = 0
    /// var list = List<Int>.Linked<2>()
    /// list.prepend(42)
    /// // Use first/last for access
    /// ```
    public typealias Index = Index_Primitives.Index<Element>
}

// NOTE: List.Linked does not support O(1) indexed subscript access due to
// its arena-based linked list structure. Element access is via iteration
// (forEach, first, last) or Input.Protocol streaming.
