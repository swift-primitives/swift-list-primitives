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

public import Buffer_Linked_Primitives

// MARK: - Copy-on-Write (Copyable elements only)

extension List.Linked where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    package mutating func makeUnique() {
        _buffer.makeUnique()
    }

    /// Adds an element to the front of the list (CoW-aware).
    ///
    /// - Parameter element: The element to prepend.
    /// - Complexity: O(1) amortized, O(n) if copy triggered
    @inlinable
    public mutating func prepend(_ element: Element) {
        makeUnique()
        ensureCapacity(count + 1)
        try! _buffer.insertFront(element)
    }

    /// Adds an element to the back of the list (CoW-aware).
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1) amortized; +O(n) if copy triggered
    @inlinable
    public mutating func append(_ element: Element) {
        makeUnique()
        ensureCapacity(count + 1)
        try! _buffer.insertBack(element)
    }

    /// Removes and returns the first element (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        makeUnique()
        return _buffer.removeFront()
    }

    /// Removes and returns the last element (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        makeUnique()
        return _buffer.removeBack()
    }

    /// Removes all elements (CoW-aware).
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        makeUnique()
        _buffer.removeAll()
        if !keepingCapacity {
            let initialCapacity = Index_Primitives.Index<Buffer<Element>.Linked<N>.Node>.Count(Cardinal(4 as UInt))
            self._buffer = try! Buffer<Element>.Linked<N>.create(capacity: initialCapacity)
        }
    }
}

// MARK: - Convenience Accessors (Copyable elements)

extension List.Linked {
    /// Returns the first element, or `nil` if empty.
    ///
    /// This is a convenience property for `Copyable` elements. For `~Copyable`
    /// elements, use ``peek`` with a closure.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        _buffer.first
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// This is a convenience property for `Copyable` elements. For `~Copyable`
    /// elements, use ``peek`` with a closure.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        _buffer.last
    }
}

// MARK: - Sequence (Copyable elements only)

extension List.Linked: Swift.Sequence where Element: Copyable {
    /// An iterator over the elements of a linked list.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        package var _inner: Buffer<Element>.Linked<N>.Iterator

        @usableFromInline
        package init(inner: Buffer<Element>.Linked<N>.Iterator) {
            self._inner = inner
        }

        @inlinable
        public mutating func next() -> Element? {
            _inner.next()
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(inner: _buffer.makeIterator())
    }
}

// MARK: - Equatable

extension List.Linked: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._buffer == rhs._buffer
    }
}

// MARK: - Hashable

extension List.Linked: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        _buffer.hash(into: &hasher)
    }
}
