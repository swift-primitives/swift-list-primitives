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

// MARK: - Initialization

extension List.Linked.Inline where Element: ~Copyable {
    /// Creates an empty inline list.
    @inlinable
    public init() {
        self.init(_buffer: .init())
    }
}

// MARK: - Properties

extension List.Linked.Inline where Element: ~Copyable {
    /// The current number of elements in the list.
    @inlinable
    public var count: Int { Int(bitPattern: _buffer.count) }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    /// Whether the list is at capacity.
    @inlinable
    public var isFull: Bool { _buffer.isFull }
}

// MARK: - Core Operations (~Copyable)

extension List.Linked.Inline where Element: ~Copyable {

    /// Adds an element to the front of the list.
    ///
    /// - Parameter element: The element to prepend.
    /// - Throws: ``Inline/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1)
    @inlinable
    public mutating func prepend(_ element: consuming Element) throws(__ListLinkedInlineError) {
        do {
            try _buffer.insertFront(element)
        } catch {
            throw .overflow
        }
    }

    /// Adds an element to the back of the list.
    ///
    /// - Parameter element: The element to append.
    /// - Throws: ``Inline/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1) (uses tail pointer for both N==1 and N==2)
    @inlinable
    public mutating func append(_ element: consuming Element) throws(__ListLinkedInlineError) {
        do {
            try _buffer.insertBack(element)
        } catch {
            throw .overflow
        }
    }

    /// Removes and returns the first element, or `nil` if empty.
    ///
    /// - Returns: The first element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        _buffer.removeFront()
    }

    /// Removes and returns the last element, or `nil` if empty.
    ///
    /// - Returns: The last element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        _buffer.removeBack()
    }

    /// Removes the first element and returns it.
    ///
    /// - Returns: The first element.
    /// - Throws: ``Inline/Error/empty`` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeFirst() throws(__ListLinkedInlineError) -> Element {
        guard let element = popFirst() else {
            throw .empty
        }
        return element
    }

    /// Removes the last element and returns it.
    ///
    /// - Returns: The last element.
    /// - Throws: ``Inline/Error/empty`` if the list is empty.
    /// - Complexity: O(1) for N >= 2, O(n) for N == 1
    @inlinable
    public mutating func removeLast() throws(__ListLinkedInlineError) -> Element {
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

// MARK: - Traversal (~Copyable)

extension List.Linked.Inline where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        try _buffer.forEach(body)
    }

    /// Calls the given closure for each element, back to front.
    ///
    /// - Precondition: N >= 2 (doubly-linked)
    /// - Complexity: O(n)
    @inlinable
    public func forEachReversed<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        try _buffer.forEachReversed(body)
    }
}

// MARK: - Peek (~Copyable)

extension List.Linked.Inline where Element: ~Copyable {
    /// Peeks at the first element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the first element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekFirst<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        try _buffer.peekFront(body)
    }

    /// Peeks at the last element without removing it.
    ///
    /// - Parameter body: A closure that receives a borrowed reference to the last element.
    /// - Returns: The result of the closure, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public func peekLast<R, E: Swift.Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R? {
        try _buffer.peekBack(body)
    }
}

// MARK: - Element Access (Copyable)

extension List.Linked.Inline where Element: Copyable {
    /// Returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        _buffer.first
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        _buffer.last
    }
}

// MARK: - ForEach (Copyable convenience)

extension List.Linked.Inline where Element: Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// Convenience overload for `Copyable` elements that accepts a non-borrowing closure.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (Element) -> Void) {
        _buffer.forEach { body($0) }
    }
}

// Note: List.Linked.Inline is unconditionally ~Copyable (Storage.Inline uses @_rawLayout),
// so it cannot conform to Swift.Sequence, Equatable, or Hashable.
// Use forEach(_:) for iteration and peekFirst/peekLast for access.

// Note: Sendable conformance is declared in List Primitives Core.
