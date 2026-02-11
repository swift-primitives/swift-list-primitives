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

// MARK: - Invariant Checking (Debug Only)

extension List.Linked.Inline where Element: Copyable {
    /// Validates internal invariants. Only runs in debug builds.
    ///
    /// Checks:
    /// - count == 0 ⇔ head == -1 && tail == -1
    /// - Traversing next from head yields exactly count nodes and ends at tail
    /// - For N >= 2: prev links are consistent, head.prev == -1, tail.next == -1
    /// - Free-list is disjoint from active list
    @usableFromInline
    func _checkInvariants() {
        #if DEBUG
        // Check empty state consistency
        if _count == 0 {
            assert(_head == -1, "Empty list must have head == -1")
            assert(_tail == -1, "Empty list must have tail == -1")
            return
        }

        // Non-empty list must have valid head and tail
        assert(_head >= 0, "Non-empty list must have valid head")
        assert(_tail >= 0, "Non-empty list must have valid tail")

        // Traverse forward and verify count
        var visitedActive = Set<Int>()
        var traversalCount = 0
        var lastVisited = -1

        var index = _head
        while index >= 0 {
            assert(!visitedActive.contains(index), "Cycle detected in active list at index \(index)")
            assert(index < capacity, "Index \(index) out of bounds")
            assert(_elements[index] != nil, "Active node at index \(index) has nil element")
            visitedActive.insert(index)
            traversalCount += 1

            // Check prev link for doubly-linked
            if N >= 2 {
                let prevIndex = _links[index][1]
                if index == _head {
                    assert(prevIndex == -1, "Head node must have prev == -1")
                } else {
                    assert(prevIndex == lastVisited, "Prev link inconsistent at index \(index)")
                }
            }

            lastVisited = index
            index = _links[index][0]
        }

        assert(traversalCount == _count, "Traversal count \(traversalCount) != _count \(_count)")
        assert(lastVisited == _tail, "Last visited \(lastVisited) != tail \(_tail)")

        // Check tail's next link
        if _tail >= 0 {
            let tailNext = _links[_tail][0]
            assert(tailNext == -1, "Tail node must have next == -1, got \(tailNext)")
        }

        // Verify free list is disjoint from active list
        if _freeHead >= 0 {
            assert(!visitedActive.contains(_freeHead), "Free list head overlaps with active list")
            // For Inline, free slots have nil elements
            assert(_elements[_freeHead] == nil, "Free slot at \(_freeHead) has non-nil element")
        }
        #endif
    }
}

// MARK: - Properties

extension List.Linked.Inline where Element: Copyable {
    /// The current number of elements in the list.
    @inlinable
    public var count: Int { _count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// Whether the list is at capacity.
    @inlinable
    public var isFull: Bool { _count >= capacity }
}

// MARK: - Core Operations

extension List.Linked.Inline where Element: Copyable {

    /// Allocates a node slot, returning its index.
    @usableFromInline
    mutating func _allocateSlot() -> Int {
        if _freeHead >= 0 {
            let index = _freeHead
            _freeHead = _links[index][0]
            return index
        }
        return _count
    }

    /// Adds an element to the front of the list.
    ///
    /// - Parameter element: The element to prepend.
    /// - Throws: ``Inline/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1)
    @inlinable
    public mutating func prepend(_ element: Element) throws(__ListLinkedInlineError) {
        guard !isFull else { throw .overflow }

        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = _head

        _elements[newIndex] = element
        _links[newIndex] = links

        if _head >= 0 && N >= 2 {
            _links[_head][1] = newIndex
        }

        if _tail < 0 {
            _tail = newIndex
        }

        _head = newIndex
        _count += 1
    }

    /// Adds an element to the back of the list.
    ///
    /// - Parameter element: The element to append.
    /// - Throws: ``Inline/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1) (uses tail pointer for both N==1 and N==2)
    @inlinable
    public mutating func append(_ element: Element) throws(__ListLinkedInlineError) {
        guard !isFull else { throw .overflow }

        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1
        if N >= 2 {
            links[1] = _tail
        }

        _elements[newIndex] = element
        _links[newIndex] = links

        if _tail >= 0 {
            _links[_tail][0] = newIndex
        }

        if _head < 0 {
            _head = newIndex
        }

        _tail = newIndex
        _count += 1
    }

    /// Removes and returns the first element, or `nil` if empty.
    ///
    /// - Returns: The first element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        guard _count > 0 else { return nil }

        let headIndex = _head
        let element = _elements[headIndex]!
        let nextIndex = _links[headIndex][0]

        // Add to free list
        _links[headIndex][0] = _freeHead
        _freeHead = headIndex

        _head = nextIndex

        if nextIndex >= 0 && N >= 2 {
            _links[nextIndex][1] = -1
        }

        if nextIndex < 0 {
            _tail = -1
        }

        _elements[headIndex] = nil
        _count -= 1
        return element
    }

    /// Removes and returns the last element, or `nil` if empty.
    ///
    /// - Returns: The last element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2 (doubly-linked), O(n) for N == 1 (singly-linked)
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        if N >= 2 {
            return _popLastDoubly()
        } else {
            return _popLastSingly()
        }
    }

    @usableFromInline
    mutating func _popLastDoubly() -> Element? {
        guard _count > 0 else { return nil }

        let tailIndex = _tail
        let prevIndex = _links[tailIndex][1]
        let element = _elements[tailIndex]!

        // Add to free list
        _links[tailIndex][0] = _freeHead
        _freeHead = tailIndex

        _tail = prevIndex

        if prevIndex >= 0 {
            _links[prevIndex][0] = -1
        } else {
            _head = -1
        }

        _elements[tailIndex] = nil
        _count -= 1
        return element
    }

    @usableFromInline
    mutating func _popLastSingly() -> Element? {
        guard _count > 0 else { return nil }

        let tailIndex = _tail

        // Find prev node (O(n) traversal)
        var prevIndex: Int = -1
        if _count > 1 {
            var current = _head
            while current >= 0 {
                let next = _links[current][0]
                if next == tailIndex {
                    prevIndex = current
                    break
                }
                current = next
            }
        }

        let element = _elements[tailIndex]!

        // Add to free list
        _links[tailIndex][0] = _freeHead
        _freeHead = tailIndex

        if prevIndex >= 0 {
            _links[prevIndex][0] = -1
        }

        _tail = prevIndex

        if prevIndex < 0 {
            _head = -1
        }

        _elements[tailIndex] = nil
        _count -= 1
        return element
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
        guard _count > 0 else { return }

        var index = _head
        while index >= 0 {
            let nextIndex = _links[index][0]
            _elements[index] = nil
            index = nextIndex
        }

        _head = -1
        _tail = -1
        _freeHead = -1
        _count = 0
    }
}

// MARK: - Element Access

extension List.Linked.Inline where Element: Copyable {
    /// Returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        guard _count > 0 else { return nil }
        return _elements[_head]!
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        guard _count > 0 else { return nil }
        return _elements[_tail]!
    }
}

// MARK: - ForEach

extension List.Linked.Inline where Element: Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (Element) -> Void) {
        var index = _head
        while index >= 0 {
            body(_elements[index]!)
            index = _links[index][0]
        }
    }

    /// Provides a reversed view of the list for iteration.
    ///
    /// Use `reversed.forEach` to iterate elements back to front.
    ///
    /// - Precondition: N >= 2 (doubly-linked)
    @inlinable
    public var reversed: Reversed {
        precondition(N >= 2, "reversed requires N >= 2 (doubly-linked)")
        return Reversed(
            _elements: _elements,
            _links: _links,
            _tail: _tail
        )
    }
}

extension List.Linked.Inline where Element: Copyable {
    /// A reversed view of the inline linked list for back-to-front iteration.
    public struct Reversed {
        @usableFromInline
        let _elements: InlineArray<capacity, Element?>

        @usableFromInline
        let _links: InlineArray<capacity, InlineArray<N, Int>>

        @usableFromInline
        let _tail: Int

        @usableFromInline
        init(
            _elements: InlineArray<capacity, Element?>,
            _links: InlineArray<capacity, InlineArray<N, Int>>,
            _tail: Int
        ) {
            self._elements = _elements
            self._links = _links
            self._tail = _tail
        }

        /// Calls the given closure for each element, back to front.
        ///
        /// - Complexity: O(n)
        @inlinable
        public func forEach(_ body: (Element) -> Void) {
            var index = _tail
            while index >= 0 {
                body(_elements[index]!)
                index = _links[index][1]
            }
        }
    }
}

// Note: List.Linked.Inline is unconditionally ~Copyable (has deinit),
// so it cannot conform to Sequence, Equatable, or Hashable.
// Use forEach(_:) for iteration and manual comparison if needed.

// Note: Sendable conformance is declared in List Primitives Core.
