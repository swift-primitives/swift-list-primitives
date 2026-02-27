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
public import Property_Primitives

// MARK: - Properties

extension List.Linked.Bounded where Element: ~Copyable {
    /// The current number of elements in the list.
    @inlinable
    public var count: Index<Element>.Count { _buffer.count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// Whether the list is at capacity.
    @inlinable
    public var isFull: Bool { _buffer.isFull }
}

// MARK: - Core Operations (~Copyable)

extension List.Linked.Bounded where Element: ~Copyable {

    /// Adds an element to the front of the list.
    ///
    /// - Parameter element: The element to prepend.
    /// - Throws: ``Bounded/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1)
    @inlinable
    public mutating func prepend(_ element: consuming Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        try! _buffer.insert.front(element)
    }

    /// Adds an element to the back of the list.
    ///
    /// - Parameter element: The element to append.
    /// - Throws: ``Bounded/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1) (uses tail pointer for both N==1 and N==2)
    @inlinable
    public mutating func append(_ element: consuming Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        try! _buffer.insert.back(element)
    }

    /// Removes and returns the first element, or `nil` if empty.
    ///
    /// - Returns: The first element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        _buffer.remove.front()
    }

    /// Removes and returns the last element, or `nil` if empty.
    ///
    /// - Returns: The last element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        _buffer.remove.back()
    }

    /// Removes the first element and returns it.
    ///
    /// - Returns: The first element.
    /// - Throws: ``Bounded/Error/empty`` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeFirst() throws(__ListLinkedBoundedError) -> Element {
        guard let element = popFirst() else {
            throw .empty
        }
        return element
    }

    /// Removes the last element and returns it.
    ///
    /// - Returns: The last element.
    /// - Throws: ``Bounded/Error/empty`` if the list is empty.
    /// - Complexity: O(1) for N >= 2, O(n) for N == 1
    @inlinable
    public mutating func removeLast() throws(__ListLinkedBoundedError) -> Element {
        guard let element = popLast() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the list.
    ///
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear() {
        _buffer.removeAll()
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension List.Linked.Bounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func ensureUnique() {
        _buffer.ensureUnique()
    }

    /// Adds an element to the front of the list (CoW-aware).
    @inlinable
    public mutating func prepend(_ element: Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        ensureUnique()
        try! _buffer.insert.front(element)
    }

    /// Adds an element to the back of the list (CoW-aware).
    @inlinable
    public mutating func append(_ element: Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        ensureUnique()
        try! _buffer.insert.back(element)
    }

    /// Removes and returns the first element (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        ensureUnique()
        return _buffer.remove.front()
    }

    /// Removes and returns the last element (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        ensureUnique()
        return _buffer.remove.back()
    }

    /// Removes all elements (CoW-aware).
    @inlinable
    public mutating func clear() {
        ensureUnique()
        _buffer.removeAll()
    }
}

// MARK: - Peek (~Copyable)

extension List.Linked.Bounded where Element: ~Copyable {
    /// Provides peek access to elements without removing them.
    ///
    /// Use `peek.first` or `peek.last` to access elements via borrowing closures.
    ///
    /// - Note: Works with `let` or `var` binding (non-mutating `_read`). For `Copyable` elements,
    ///   use ``first`` and ``last`` properties directly.
    @inlinable
    public var peek: Property<Peek, Self>.View.Read.Typed<Element>.Valued<N> {
        _read {
            yield Property<Peek, Self>.View.Read.Typed<Element>.Valued<N>(
                borrowing: self
            )
        }
    }
}

extension Property.View.Read.Typed.Valued
where Tag == List<Element>.Linked<n>.Bounded.Peek,
      Base == List<Element>.Linked<n>.Bounded,
      Element: ~Copyable
{
    /// Peeks at the first element of a bounded list without removing it.
    @inlinable
    public func first<R>(
        _ body: (borrowing Element) -> R
    ) -> R? {
        unsafe base.pointee._buffer.peekFront(body)
    }

    /// Peeks at the last element of a bounded list without removing it.
    @inlinable
    public func last<R>(
        _ body: (borrowing Element) -> R
    ) -> R? {
        unsafe base.pointee._buffer.peekBack(body)
    }
}

extension List.Linked.Bounded {
    /// Returns the first element, or `nil` if empty.
    @inlinable
    public var first: Element? {
        _buffer.first
    }

    /// Returns the last element, or `nil` if empty.
    @inlinable
    public var last: Element? {
        _buffer.last
    }
}

// MARK: - Conditional Drain

extension List.Linked.Bounded where Element: Copyable {
    /// Drains elements front-to-back while the predicate returns true.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        _ body: (consuming Element) -> Void
    ) {
        ensureUnique()
        while let element = first, predicate(element) {
            body(popFirst()!)
        }
    }
}

// MARK: - ForEach

extension List.Linked.Bounded where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        _buffer.forEach(body)
    }

    /// Provides a reversed view of the list for iteration.
    ///
    /// - Precondition: N >= 2 (doubly-linked)
    /// - Note: Works with `let` or `var` binding (non-mutating `_read`).
    @inlinable
    public var reversed: Property<Reversed, Self>.View.Read.Typed<Element>.Valued<N> {
        _read {
            precondition(N >= 2, "reversed requires N >= 2 (doubly-linked)")
            yield Property<Reversed, Self>.View.Read.Typed<Element>.Valued<N>(
                borrowing: self
            )
        }
    }
}

extension Property.View.Read.Typed.Valued
where Tag == List<Element>.Linked<n>.Bounded.Reversed,
      Base == List<Element>.Linked<n>.Bounded,
      Element: ~Copyable
{
    /// Calls the given closure for each element of a bounded list, back to front.
    @inlinable
    public func forEach(
        _ body: (borrowing Element) -> Void
    ) {
        unsafe base.pointee._buffer.forEachReversed(body)
    }
}

// MARK: - Sequence (Copyable elements only)

extension List.Linked.Bounded: Swift.Sequence where Element: Copyable {
    /// An iterator over the elements of a bounded linked list.
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        var _inner: Buffer<Element>.Linked<N>.Iterator

        @usableFromInline
        init(inner: Buffer<Element>.Linked<N>.Iterator) {
            self._inner = inner
        }

        @_lifetime(&self)
        @inlinable
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            _inner.nextSpan(maximumCount: maximumCount)
        }

        @_lifetime(self: immortal)
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

extension List.Linked.Bounded: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._buffer == rhs._buffer
    }
}

// MARK: - Hashable

extension List.Linked.Bounded: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        _buffer.hash(into: &hasher)
    }
}
