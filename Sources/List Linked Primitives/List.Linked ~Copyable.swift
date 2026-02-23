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

extension List.Linked where Element: ~Copyable {
    /// The current number of elements in the list.
    @inlinable
    public var count: Index<Element>.Count { _buffer.count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// The current capacity of the list.
    @inlinable
    public var capacity: Index<Element>.Count { _buffer.capacity.retag(Element.self) }
}

// MARK: - Capacity Management

extension List.Linked where Element: ~Copyable {
    /// Ensures the list has capacity for one additional element.
    @usableFromInline
    package mutating func ensureCapacityForOneMore() {
        try! _buffer.ensureCapacity(Int(bitPattern: _buffer.count) + 1)
    }

    /// Reserves capacity for at least the specified number of elements.
    ///
    /// Use this method to avoid multiple reallocations when adding a known
    /// number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum total capacity to reserve.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        try! _buffer.ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (~Copyable)

extension List.Linked where Element: ~Copyable {

    /// Adds an element to the front of the list.
    ///
    /// - Parameter element: The element to prepend.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func prepend(_ element: consuming Element) {
        ensureCapacityForOneMore()
        try! _buffer.insert.front(element)
    }

    /// Adds an element to the back of the list.
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1) amortized (uses tail pointer for both N==1 and N==2)
    @inlinable
    public mutating func append(_ element: consuming Element) {
        ensureCapacityForOneMore()
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
    /// - Throws: ``Linked/Error/empty`` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeFirst() throws(List<Element>.Linked<N>.Error) -> Element {
        guard let element = popFirst() else {
            throw .empty
        }
        return element
    }

    /// Removes the last element and returns it.
    ///
    /// - Returns: The last element.
    /// - Throws: ``Linked/Error/empty`` if the list is empty.
    /// - Complexity: O(1) for N >= 2, O(n) for N == 1
    @inlinable
    public mutating func removeLast() throws(List<Element>.Linked<N>.Error) -> Element {
        guard let element = popLast() else {
            throw .empty
        }
        return element
    }

    /// Removes all elements from the list.
    ///
    /// - Parameter keepingCapacity: If `true`, the list keeps its current capacity.
    ///   If `false`, the storage is released. Default is `true`.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.removeAll()
        if !keepingCapacity {
            self._buffer = try! .create(capacity: 4)
        }
    }
}

// MARK: - Peek (~Copyable)

extension List.Linked where Element: ~Copyable {
    /// Provides peek access to elements without removing them.
    ///
    /// Use `peek.first` or `peek.last` to access elements via borrowing closures.
    ///
    /// ## Example
    ///
    /// ```swift
    /// list.peek.first { element in
    ///     print(element)
    /// }
    /// ```
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
where Tag == List<Element>.Linked<n>.Peek,
      Base == List<Element>.Linked<n>,
      Element: ~Copyable
{
    /// Peeks at the first element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the first element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func first<R>(
        _ body: (borrowing Element) -> R
    ) -> R? {
        unsafe base.pointee._buffer.peekFront(body)
    }

    /// Peeks at the last element without removing it.
    ///
    /// Uses a closure to support `~Copyable` elements via borrowing.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the last element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func last<R>(
        _ body: (borrowing Element) -> R
    ) -> R? {
        unsafe base.pointee._buffer.peekBack(body)
    }
}

// MARK: - ForEach

extension List.Linked where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        _buffer.forEach(body)
    }

    /// Provides a reversed view of the list for iteration.
    ///
    /// Use `reversed.forEach` to iterate elements back to front.
    ///
    /// ## Example
    ///
    /// ```swift
    /// list.reversed.forEach { element in
    ///     print(element)
    /// }
    /// ```
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
where Tag == List<Element>.Linked<n>.Reversed,
      Base == List<Element>.Linked<n>,
      Element: ~Copyable
{
    /// Calls the given closure for each element, back to front.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(
        _ body: (borrowing Element) -> Void
    ) {
        unsafe base.pointee._buffer.forEachReversed(body)
    }
}
