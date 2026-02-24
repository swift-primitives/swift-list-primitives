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

// MARK: - CoW-Safe Mutations (Copyable elements only)

extension List.Linked where Element: Copyable {
    /// Adds an element to the front of the list (CoW-safe).
    ///
    /// - Parameter element: The element to prepend.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func prepend(_ element: Element) {
        _buffer.insert.front(element)
    }

    /// Adds an element to the back of the list (CoW-safe).
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func append(_ element: Element) {
        _buffer.insert.back(element)
    }

    /// Removes and returns the first element (CoW-safe).
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        _buffer.remove.front()
    }

    /// Removes and returns the last element (CoW-safe).
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        _buffer.remove.back()
    }

    /// Removes all elements (CoW-safe).
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.removeAll()
        if !keepingCapacity {
            self._buffer = try! .create(capacity: 4)
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

// MARK: - Conditional Drain

extension List.Linked where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true.
    ///
    /// Repeatedly peeks at the first element; if the predicate returns true,
    /// removes and passes it to body; if false, stops.
    /// The list survives with remaining elements intact.
    ///
    /// - Parameters:
    ///   - predicate: A closure that receives a borrowed reference to the first element.
    ///     Return `true` to drain it, `false` to stop.
    ///   - body: A closure that receives each drained element with ownership.
    /// - Complexity: O(k) where k is the number of elements drained.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        while let element = first, predicate(element) {
            body(popFirst()!)
        }
    }
}

// MARK: - Sequence (Copyable elements only)

extension List.Linked: Swift.Sequence where Element: Copyable {
    /// An iterator over the elements of a linked list.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
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
