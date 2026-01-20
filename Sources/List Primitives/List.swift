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

/// Doubly-linked list with O(1) prepend, append, and removal at either end.
///
/// `List` provides a doubly-linked list implementation that supports efficient
/// insertion and removal at both ends. Unlike array-based collections, linked
/// lists provide O(1) insertion and removal at arbitrary positions given a node
/// reference.
///
/// ## Example
///
/// ```swift
/// var list = List<Int>()
/// list.append(1)
/// list.append(2)
/// list.prepend(0)
/// list.popFirst()  // 0
/// list.popLast()   // 2
/// ```
///
/// ## Performance
///
/// | Operation | Complexity |
/// |-----------|------------|
/// | prepend   | O(1)       |
/// | append    | O(1)       |
/// | popFirst  | O(1)       |
/// | popLast   | O(1)       |
/// | count     | O(1)       |
///
/// ## Memory
///
/// Each element is stored in a separate node allocation. For dense storage
/// of small elements, consider `Array` or `Stack` instead.
public struct List<Element> {
    /// A node in the linked list.
    @usableFromInline
    final class Node {
        @usableFromInline
        var element: Element

        @usableFromInline
        var next: Node?

        @usableFromInline
        var prev: Node?

        @inlinable
        init(element: Element) {
            self.element = element
            self.next = nil
            self.prev = nil
        }
    }

    @usableFromInline
    var _head: Node?

    @usableFromInline
    var _tail: Node?

    @usableFromInline
    var _count: Int

    /// Creates an empty list.
    @inlinable
    public init() {
        self._head = nil
        self._tail = nil
        self._count = 0
    }

    // MARK: - Singly-Linked Variant

    /// Singly-linked list with O(1) prepend and O(1) popFirst.
    ///
    /// `List.Singly` provides a singly-linked list that uses less memory per node
    /// than `List` but only supports efficient operations at the front.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var list = List<Int>.Singly()
    /// list.prepend(1)
    /// list.prepend(2)
    /// list.popFirst()  // 2
    /// ```
    ///
    /// ## Performance
    ///
    /// | Operation | Complexity |
    /// |-----------|------------|
    /// | prepend   | O(1)       |
    /// | append    | O(1)       |
    /// | popFirst  | O(1)       |
    /// | popLast   | O(n)       |
    public struct Singly {
        /// A node in the singly-linked list.
        @usableFromInline
        final class Node {
            @usableFromInline
            var element: Element

            @usableFromInline
            var next: Node?

            @inlinable
            init(element: Element) {
                self.element = element
                self.next = nil
            }
        }

        @usableFromInline
        var _head: Node?

        @usableFromInline
        var _tail: Node?

        @usableFromInline
        var _count: Int

        /// Creates an empty singly-linked list.
        @inlinable
        public init() {
            self._head = nil
            self._tail = nil
            self._count = 0
        }
    }
}

// MARK: - Properties

extension List {
    /// The number of elements in the list.
    @inlinable
    public var count: Int { _count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Returns a copy of the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        _head?.element
    }

    /// Returns a copy of the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        _tail?.element
    }
}

extension List.Singly {
    /// The number of elements in the list.
    @inlinable
    public var count: Int { _count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Returns a copy of the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        _head?.element
    }

    /// Returns a copy of the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        _tail?.element
    }
}

// MARK: - Prepend/Append

extension List {
    /// Adds an element to the front of the list.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func prepend(_ element: Element) {
        let node = Node(element: element)
        if let head = _head {
            node.next = head
            head.prev = node
            _head = node
        } else {
            _head = node
            _tail = node
        }
        _count += 1
    }

    /// Adds an element to the back of the list.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func append(_ element: Element) {
        let node = Node(element: element)
        if let tail = _tail {
            node.prev = tail
            tail.next = node
            _tail = node
        } else {
            _head = node
            _tail = node
        }
        _count += 1
    }
}

extension List.Singly {
    /// Adds an element to the front of the list.
    ///
    /// - Complexity: O(1)
    @inlinable
    public mutating func prepend(_ element: Element) {
        let node = Node(element: element)
        if let head = _head {
            node.next = head
            _head = node
        } else {
            _head = node
            _tail = node
        }
        _count += 1
    }

    /// Adds an element to the back of the list.
    ///
    /// - Complexity: O(1) - we maintain a tail pointer
    @inlinable
    public mutating func append(_ element: Element) {
        let node = Node(element: element)
        if let tail = _tail {
            tail.next = node
            _tail = node
        } else {
            _head = node
            _tail = node
        }
        _count += 1
    }
}

// MARK: - Pop Operations

extension List {
    /// Removes and returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        guard let head = _head else { return nil }

        let element = head.element
        _head = head.next
        if let newHead = _head {
            newHead.prev = nil
        } else {
            _tail = nil
        }
        head.next = nil
        _count -= 1
        return element
    }

    /// Removes and returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        guard let tail = _tail else { return nil }

        let element = tail.element
        _tail = tail.prev
        if let newTail = _tail {
            newTail.next = nil
        } else {
            _head = nil
        }
        tail.prev = nil
        _count -= 1
        return element
    }
}

extension List.Singly {
    /// Removes and returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        guard let head = _head else { return nil }

        let element = head.element
        _head = head.next
        if _head == nil {
            _tail = nil
        }
        head.next = nil
        _count -= 1
        return element
    }

    /// Removes and returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(n) - must traverse to find the node before tail
    ///
    /// For frequent popLast operations, consider using `List` (doubly-linked) instead.
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        guard let head = _head else { return nil }

        // Single element case
        if head.next == nil {
            let element = head.element
            _head = nil
            _tail = nil
            _count -= 1
            return element
        }

        // Find the node before tail
        var current = head
        while let next = current.next, next.next != nil {
            current = next
        }

        // current is now the node before tail
        let tail = current.next!
        let element = tail.element
        current.next = nil
        _tail = current
        _count -= 1
        return element
    }
}

// MARK: - Clear

extension List {
    /// Removes all elements from the list.
    ///
    /// - Complexity: O(n)
    @inlinable
    public mutating func clear() {
        // Walk the list and break cycles for deterministic cleanup
        var current = _head
        while let node = current {
            let next = node.next
            node.prev = nil
            node.next = nil
            current = next
        }
        _head = nil
        _tail = nil
        _count = 0
    }
}

extension List.Singly {
    /// Removes all elements from the list.
    ///
    /// - Complexity: O(n)
    @inlinable
    public mutating func clear() {
        var current = _head
        while let node = current {
            let next = node.next
            node.next = nil
            current = next
        }
        _head = nil
        _tail = nil
        _count = 0
    }
}

// MARK: - ForEach

extension List {
    /// Calls the given closure for each element in the list, from front to back.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (Element) -> Void) {
        var current = _head
        while let node = current {
            body(node.element)
            current = node.next
        }
    }

    /// Calls the given closure for each element in the list, from back to front.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEachReversed(_ body: (Element) -> Void) {
        var current = _tail
        while let node = current {
            body(node.element)
            current = node.prev
        }
    }
}

extension List.Singly {
    /// Calls the given closure for each element in the list, from front to back.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (Element) -> Void) {
        var current = _head
        while let node = current {
            body(node.element)
            current = node.next
        }
    }
}

// MARK: - Sequence Conformance

extension List: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        var _current: Node?

        @usableFromInline
        init(_current: Node?) {
            self._current = _current
        }

        @inlinable
        public mutating func next() -> Element? {
            guard let node = _current else { return nil }
            _current = node.next
            return node.element
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_current: _head)
    }
}

extension List.Singly: Sequence {
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        var _current: List.Singly.Node?

        @usableFromInline
        init(_current: List.Singly.Node?) {
            self._current = _current
        }

        @inlinable
        public mutating func next() -> Element? {
            guard let node = _current else { return nil }
            _current = node.next
            return node.element
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(_current: _head)
    }
}

// MARK: - Equatable

extension List: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: List, rhs: List) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var lhsNode = lhs._head
        var rhsNode = rhs._head
        while let l = lhsNode, let r = rhsNode {
            if l.element != r.element { return false }
            lhsNode = l.next
            rhsNode = r.next
        }
        return true
    }
}

extension List.Singly: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: List.Singly, rhs: List.Singly) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var lhsNode = lhs._head
        var rhsNode = rhs._head
        while let l = lhsNode, let r = rhsNode {
            if l.element != r.element { return false }
            lhsNode = l.next
            rhsNode = r.next
        }
        return true
    }
}

// MARK: - Hashable

extension List: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        var current = _head
        while let node = current {
            hasher.combine(node.element)
            current = node.next
        }
    }
}

extension List.Singly: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_count)
        var current = _head
        while let node = current {
            hasher.combine(node.element)
            current = node.next
        }
    }
}

// MARK: - Sendable

extension List: @unchecked Sendable where Element: Sendable {}
extension List.Singly: @unchecked Sendable where Element: Sendable {}
