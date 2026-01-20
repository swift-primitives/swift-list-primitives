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

extension List.Linked.Small where Element: Copyable {
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

        if let heap = _heap {
            // Heap mode: use Storage's raw pointers
            _checkInvariantsHeap(heap)
        } else {
            // Inline mode: use inline arrays
            _checkInvariantsInline()
        }
        #endif
    }

    #if DEBUG
    private func _checkInvariantsHeap(_ heap: List<Element>.Linked<N>.Storage) {
        var visitedActive = Set<Int>()
        var traversalCount = 0
        var lastVisited = -1

        _ = unsafe heap.withUnsafeMutablePointerToElements { nodes in
            var index = heap.header.head
            while index >= 0 {
                assert(!visitedActive.contains(index), "Cycle detected in active list at index \(index)")
                assert(index < heap.capacity, "Index \(index) out of bounds")
                visitedActive.insert(index)
                traversalCount += 1

                // Check prev link for doubly-linked
                if N >= 2 {
                    let prevIndex = unsafe nodes[index].links[1]
                    if index == heap.header.head {
                        assert(prevIndex == -1, "Head node must have prev == -1")
                    } else {
                        assert(prevIndex == lastVisited, "Prev link inconsistent at index \(index)")
                    }
                }

                lastVisited = index
                index = unsafe nodes[index].nextIndex
            }
        }

        assert(traversalCount == heap.header.count, "Traversal count \(traversalCount) != count \(heap.header.count)")
        assert(lastVisited == heap.header.tail, "Last visited \(lastVisited) != tail \(heap.header.tail)")

        // Check tail's next link
        if heap.header.tail >= 0 {
            _ = unsafe heap.withUnsafeMutablePointerToElements { nodes in
                let tailNext = unsafe nodes[heap.header.tail].nextIndex
                assert(tailNext == -1, "Tail node must have next == -1, got \(tailNext)")
            }
        }

        // Verify free list head is disjoint from active list
        if heap.header.freeHead >= 0 {
            assert(!visitedActive.contains(heap.header.freeHead), "Free list head overlaps with active list")
        }
    }

    private func _checkInvariantsInline() {
        var visitedActive = Set<Int>()
        var traversalCount = 0
        var lastVisited = -1

        var index = _head
        while index >= 0 {
            assert(!visitedActive.contains(index), "Cycle detected in active list at index \(index)")
            assert(index < inlineCapacity, "Index \(index) out of bounds")
            assert(_inlineElements[index] != nil, "Active node at index \(index) has nil element")
            visitedActive.insert(index)
            traversalCount += 1

            // Check prev link for doubly-linked
            if N >= 2 {
                let prevIndex = _inlineLinks[index][1]
                if index == _head {
                    assert(prevIndex == -1, "Head node must have prev == -1")
                } else {
                    assert(prevIndex == lastVisited, "Prev link inconsistent at index \(index)")
                }
            }

            lastVisited = index
            index = _inlineLinks[index][0]
        }

        assert(traversalCount == _count, "Traversal count \(traversalCount) != _count \(_count)")
        assert(lastVisited == _tail, "Last visited \(lastVisited) != tail \(_tail)")

        // Check tail's next link
        if _tail >= 0 {
            let tailNext = _inlineLinks[_tail][0]
            assert(tailNext == -1, "Tail node must have next == -1, got \(tailNext)")
        }

        // Verify free list is disjoint from active list
        if _freeHead >= 0 {
            assert(!visitedActive.contains(_freeHead), "Free list head overlaps with active list")
            // For inline mode, free slots have nil elements
            assert(_inlineElements[_freeHead] == nil, "Free slot at \(_freeHead) has non-nil element")
        }
    }
    #endif
}

// MARK: - Properties

extension List.Linked.Small where Element: Copyable {
    /// The current number of elements in the list.
    @inlinable
    public var count: Int { _count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _count == 0 }

    /// The current capacity of the list.
    @inlinable
    public var capacity: Int {
        if let heap = _heap {
            return heap.capacity
        }
        return inlineCapacity
    }
}

// MARK: - Core Operations

extension List.Linked.Small where Element: Copyable {

    /// Spills inline storage to heap, linearizing the list.
    @usableFromInline
    mutating func _spillToHeap(minimumCapacity: Int) {
        precondition(_heap == nil, "Already spilled")

        let newCapacity = Swift.max(minimumCapacity, inlineCapacity * 2, 8)
        let newStorage = List<Element>.Linked<N>.Storage.create(minimumCapacity: newCapacity)

        // Move elements from inline to heap
        var srcIndex = _head
        var dstIndex = 0
        _ = unsafe newStorage.withUnsafeMutablePointerToElements { heapNodes in
            while srcIndex >= 0 {
                let nextSrcIndex = _inlineLinks[srcIndex][0]
                var newLinks = InlineArray<N, Int>(repeating: -1)
                newLinks[0] = dstIndex + 1 < _count ? dstIndex + 1 : -1
                if N >= 2 {
                    newLinks[1] = dstIndex > 0 ? dstIndex - 1 : -1
                }
                unsafe (heapNodes + dstIndex).initialize(
                    to: List<Element>.Linked<N>.Node(
                        element: _inlineElements[srcIndex]!,
                        links: newLinks
                    )
                )
                _inlineElements[srcIndex] = nil
                srcIndex = nextSrcIndex
                dstIndex += 1
            }
        }

        newStorage.header.head = _count > 0 ? 0 : -1
        newStorage.header.tail = _count > 0 ? _count - 1 : -1
        newStorage.header.count = _count

        _heap = newStorage
        _head = newStorage.header.head
        _tail = newStorage.header.tail
        _freeHead = -1
    }

    /// Allocates a node slot (inline mode), returning its index.
    @usableFromInline
    mutating func _allocateInlineSlot() -> Int {
        if _freeHead >= 0 {
            let index = _freeHead
            _freeHead = _inlineLinks[index][0]
            return index
        }
        return _count
    }

    /// Allocates a node slot (heap mode), returning its index.
    @usableFromInline
    mutating func _allocateHeapSlot() -> Int {
        if _heap!.header.freeHead >= 0 {
            let index = _heap!.header.freeHead
            _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
                _heap!.header.freeHead = unsafe nodes[index].nextIndex
            }
            return index
        }
        return _heap!.header.count
    }

    /// Ensures heap has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func _ensureHeapCapacity(_ minimumCapacity: Int) {
        guard let heap = _heap else {
            _spillToHeap(minimumCapacity: minimumCapacity)
            return
        }

        guard heap.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, heap.capacity * 2, 8)
        let newStorage = List<Element>.Linked<N>.Storage.create(minimumCapacity: newCapacity)

        heap._moveAllElements(to: newStorage)
        newStorage.header.head = heap.header.count > 0 ? 0 : -1
        newStorage.header.tail = heap.header.count > 0 ? heap.header.count - 1 : -1
        newStorage.header.count = heap.header.count

        _heap = newStorage
        _head = newStorage.header.head
        _tail = newStorage.header.tail
    }

    /// Adds an element to the front of the list.
    ///
    /// - Parameter element: The element to prepend.
    /// - Complexity: O(1) amortized
    @inlinable
    public mutating func prepend(_ element: Element) {
        if _heap != nil {
            _prependToHeap(element)
        } else if _count < inlineCapacity {
            _prependToInline(element)
        } else {
            _spillToHeap(minimumCapacity: inlineCapacity + 1)
            _prependToHeap(element)
        }
    }

    @usableFromInline
    mutating func _prependToInline(_ element: Element) {
        let newIndex = _allocateInlineSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = _head

        _inlineElements[newIndex] = element
        _inlineLinks[newIndex] = links

        if _head >= 0 && N >= 2 {
            _inlineLinks[_head][1] = newIndex
        }

        if _tail < 0 {
            _tail = newIndex
        }

        _head = newIndex
        _count += 1
    }

    @usableFromInline
    mutating func _prependToHeap(_ element: Element) {
        _ensureHeapCapacity(_count + 1)
        let newIndex = _allocateHeapSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = _head

        _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + newIndex).initialize(
                to: List<Element>.Linked<N>.Node(element: element, links: links)
            )

            if _head >= 0 && N >= 2 {
                unsafe (nodes[_head].links[1] = newIndex)
            }
        }

        if _tail < 0 {
            _tail = newIndex
        }

        _head = newIndex
        _count += 1
        _heap!.header.head = _head
        _heap!.header.tail = _tail
        _heap!.header.count = _count
    }

    /// Adds an element to the back of the list.
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1) for N >= 2, O(n) for N == 1
    @inlinable
    public mutating func append(_ element: Element) {
        if _heap != nil {
            _appendToHeap(element)
        } else if _count < inlineCapacity {
            _appendToInline(element)
        } else {
            _spillToHeap(minimumCapacity: inlineCapacity + 1)
            _appendToHeap(element)
        }
    }

    @usableFromInline
    mutating func _appendToInline(_ element: Element) {
        let newIndex = _allocateInlineSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1
        if N >= 2 {
            links[1] = _tail
        }

        _inlineElements[newIndex] = element
        _inlineLinks[newIndex] = links

        if _tail >= 0 {
            _inlineLinks[_tail][0] = newIndex
        }

        if _head < 0 {
            _head = newIndex
        }

        _tail = newIndex
        _count += 1
    }

    @usableFromInline
    mutating func _appendToHeap(_ element: Element) {
        _ensureHeapCapacity(_count + 1)
        let newIndex = _allocateHeapSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1
        if N >= 2 {
            links[1] = _tail
        }

        _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + newIndex).initialize(
                to: List<Element>.Linked<N>.Node(element: element, links: links)
            )

            if _tail >= 0 {
                unsafe (nodes[_tail].links[0] = newIndex)
            }
        }

        if _head < 0 {
            _head = newIndex
        }

        _tail = newIndex
        _count += 1
        _heap!.header.head = _head
        _heap!.header.tail = _tail
        _heap!.header.count = _count
    }

    /// Removes and returns the first element, or `nil` if empty.
    ///
    /// - Returns: The first element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        guard _count > 0 else { return nil }

        if _heap != nil {
            return _popFirstFromHeap()
        } else {
            return _popFirstFromInline()
        }
    }

    @usableFromInline
    mutating func _popFirstFromInline() -> Element? {
        let headIndex = _head
        let element = _inlineElements[headIndex]!
        let nextIndex = _inlineLinks[headIndex][0]

        _inlineLinks[headIndex][0] = _freeHead
        _freeHead = headIndex

        _head = nextIndex

        if nextIndex >= 0 && N >= 2 {
            _inlineLinks[nextIndex][1] = -1
        }

        if nextIndex < 0 {
            _tail = -1
        }

        _inlineElements[headIndex] = nil
        _count -= 1
        return element
    }

    @usableFromInline
    mutating func _popFirstFromHeap() -> Element? {
        let headIndex = _head
        var element: Element?
        var nextIndex: Int = -1

        _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
            element = unsafe nodes[headIndex].element
            nextIndex = unsafe nodes[headIndex].nextIndex
            unsafe (nodes + headIndex).deinitialize(count: 1)
            unsafe (nodes[headIndex].links[0] = _heap!.header.freeHead)
        }

        _heap!.header.freeHead = headIndex
        _head = nextIndex

        if nextIndex >= 0 && N >= 2 {
            _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
                unsafe (nodes[nextIndex].links[1] = -1)
            }
        }

        if nextIndex < 0 {
            _tail = -1
        }

        _count -= 1
        _heap!.header.head = _head
        _heap!.header.tail = _tail
        _heap!.header.count = _count
        return element
    }

    /// Removes and returns the last element, or `nil` if empty.
    ///
    /// - Returns: The last element, or `nil` if the list is empty.
    /// - Complexity: O(1) for N >= 2, O(n) for N == 1
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        guard _count > 0 else { return nil }

        if _heap != nil {
            if N >= 2 {
                return _popLastDoublyFromHeap()
            } else {
                return _popLastSinglyFromHeap()
            }
        } else {
            if N >= 2 {
                return _popLastDoublyFromInline()
            } else {
                return _popLastSinglyFromInline()
            }
        }
    }

    @usableFromInline
    mutating func _popLastDoublyFromInline() -> Element? {
        let tailIndex = _tail
        let prevIndex = _inlineLinks[tailIndex][1]
        let element = _inlineElements[tailIndex]!

        _inlineLinks[tailIndex][0] = _freeHead
        _freeHead = tailIndex

        _tail = prevIndex

        if prevIndex >= 0 {
            _inlineLinks[prevIndex][0] = -1
        } else {
            _head = -1
        }

        _inlineElements[tailIndex] = nil
        _count -= 1
        return element
    }

    @usableFromInline
    mutating func _popLastSinglyFromInline() -> Element? {
        let tailIndex = _tail

        var prevIndex: Int = -1
        if _count > 1 {
            var current = _head
            while current >= 0 {
                let next = _inlineLinks[current][0]
                if next == tailIndex {
                    prevIndex = current
                    break
                }
                current = next
            }
        }

        let element = _inlineElements[tailIndex]!

        _inlineLinks[tailIndex][0] = _freeHead
        _freeHead = tailIndex

        if prevIndex >= 0 {
            _inlineLinks[prevIndex][0] = -1
        }

        _tail = prevIndex

        if prevIndex < 0 {
            _head = -1
        }

        _inlineElements[tailIndex] = nil
        _count -= 1
        return element
    }

    @usableFromInline
    mutating func _popLastDoublyFromHeap() -> Element? {
        let tailIndex = _tail
        var element: Element?
        var prevIndex: Int = -1

        _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
            prevIndex = unsafe nodes[tailIndex].links[1]
            element = unsafe nodes[tailIndex].element
            unsafe (nodes + tailIndex).deinitialize(count: 1)
            unsafe (nodes[tailIndex].links[0] = _heap!.header.freeHead)
        }

        _heap!.header.freeHead = tailIndex
        _tail = prevIndex

        if prevIndex >= 0 {
            _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
                unsafe (nodes[prevIndex].links[0] = -1)
            }
        } else {
            _head = -1
        }

        _count -= 1
        _heap!.header.head = _head
        _heap!.header.tail = _tail
        _heap!.header.count = _count
        return element
    }

    @usableFromInline
    mutating func _popLastSinglyFromHeap() -> Element? {
        let tailIndex = _tail

        var prevIndex: Int = -1
        if _count > 1 {
            var current = _head
            _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
                while current >= 0 {
                    let next = unsafe nodes[current].nextIndex
                    if next == tailIndex {
                        prevIndex = current
                        break
                    }
                    current = next
                }
            }
        }

        var element: Element?

        _ = unsafe _heap!.withUnsafeMutablePointerToElements { nodes in
            element = unsafe nodes[tailIndex].element
            unsafe (nodes + tailIndex).deinitialize(count: 1)
            unsafe (nodes[tailIndex].links[0] = _heap!.header.freeHead)

            if prevIndex >= 0 {
                unsafe (nodes[prevIndex].links[0] = -1)
            }
        }

        _heap!.header.freeHead = tailIndex
        _tail = prevIndex

        if prevIndex < 0 {
            _head = -1
        }

        _count -= 1
        _heap!.header.head = _head
        _heap!.header.tail = _tail
        _heap!.header.count = _count
        return element
    }

    /// Removes the first element and returns it.
    ///
    /// - Returns: The first element.
    /// - Throws: ``Small/Error/empty`` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    public mutating func removeFirst() throws(__ListLinkedSmallError) -> Element {
        guard let element = popFirst() else {
            throw .empty
        }
        return element
    }

    /// Removes the last element and returns it.
    ///
    /// - Returns: The last element.
    /// - Throws: ``Small/Error/empty`` if the list is empty.
    /// - Complexity: O(1) for N >= 2, O(n) for N == 1
    @inlinable
    public mutating func removeLast() throws(__ListLinkedSmallError) -> Element {
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

        if _heap != nil {
            // Heap storage handles cleanup via deinit when we nil it
            _heap = nil
        } else {
            // Clean up inline storage
            var index = _head
            while index >= 0 {
                let nextIndex = _inlineLinks[index][0]
                _inlineElements[index] = nil
                index = nextIndex
            }
        }

        _head = -1
        _tail = -1
        _freeHead = -1
        _count = 0
    }
}

// MARK: - Element Access

extension List.Linked.Small where Element: Copyable {
    /// Returns the first element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        guard _count > 0 else { return nil }

        if let heap = _heap {
            return unsafe heap.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[_head].element
            }
        } else {
            return _inlineElements[_head]!
        }
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var last: Element? {
        guard _count > 0 else { return nil }

        if let heap = _heap {
            return unsafe heap.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[_tail].element
            }
        } else {
            return _inlineElements[_tail]!
        }
    }
}

// MARK: - ForEach

extension List.Linked.Small where Element: Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Complexity: O(n)
    @inlinable
    public func forEach(_ body: (Element) -> Void) {
        var index = _head

        if let heap = _heap {
            _ = unsafe heap.withUnsafeMutablePointerToElements { nodes in
                while index >= 0 {
                    body(unsafe nodes[index].element)
                    index = unsafe nodes[index].nextIndex
                }
            }
        } else {
            while index >= 0 {
                body(_inlineElements[index]!)
                index = _inlineLinks[index][0]
            }
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
            _inlineElements: _inlineElements,
            _inlineLinks: _inlineLinks,
            _heap: _heap,
            _tail: _tail
        )
    }
}

extension List.Linked.Small where Element: Copyable {
    /// A reversed view of the small linked list for back-to-front iteration.
    public struct Reversed {
        @usableFromInline
        let _inlineElements: InlineArray<inlineCapacity, Element?>

        @usableFromInline
        let _inlineLinks: InlineArray<inlineCapacity, InlineArray<N, Int>>

        @usableFromInline
        let _heap: List<Element>.Linked<N>.Storage?

        @usableFromInline
        let _tail: Int

        @usableFromInline
        init(
            _inlineElements: InlineArray<inlineCapacity, Element?>,
            _inlineLinks: InlineArray<inlineCapacity, InlineArray<N, Int>>,
            _heap: List<Element>.Linked<N>.Storage?,
            _tail: Int
        ) {
            self._inlineElements = _inlineElements
            self._inlineLinks = _inlineLinks
            self._heap = _heap
            self._tail = _tail
        }

        /// Calls the given closure for each element, back to front.
        ///
        /// - Complexity: O(n)
        @inlinable
        public func forEach(_ body: (Element) -> Void) {
            var index = _tail

            if let heap = _heap {
                _ = unsafe heap.withUnsafeMutablePointerToElements { nodes in
                    while index >= 0 {
                        body(unsafe nodes[index].element)
                        index = unsafe nodes[index].links[1]
                    }
                }
            } else {
                while index >= 0 {
                    body(_inlineElements[index]!)
                    index = _inlineLinks[index][1]
                }
            }
        }
    }
}

// Note: List.Linked.Small is unconditionally ~Copyable (has deinit),
// so it cannot conform to Sequence, Equatable, or Hashable.
// Use forEach(_:) for iteration and manual comparison if needed.

// MARK: - Sendable

extension List.Linked.Small: @unchecked Sendable where Element: Sendable {}
