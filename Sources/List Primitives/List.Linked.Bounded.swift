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

// MARK: - Properties

extension List.Linked.Bounded where Element: ~Copyable {
    /// The current number of elements in the list.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// Whether the list is at capacity.
    @inlinable
    public var isFull: Bool { _storage.header.count >= capacity }
}

// MARK: - Invariant Checking (Debug Only)

extension List.Linked.Bounded where Element: ~Copyable {
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
        let header = _storage.header

        // Check empty state consistency
        if header.count == 0 {
            assert(header.head == -1, "Empty list must have head == -1")
            assert(header.tail == -1, "Empty list must have tail == -1")
            return
        }

        // Non-empty list must have valid head and tail
        assert(header.head >= 0, "Non-empty list must have valid head")
        assert(header.tail >= 0, "Non-empty list must have valid tail")

        // Traverse forward and verify count
        var visitedActive = Set<Int>()
        var traversalCount = 0
        var lastVisited = -1

        var index = header.head
        while index >= 0 {
            assert(!visitedActive.contains(index), "Cycle detected in active list at index \(index)")
            assert(index < capacity, "Index \(index) out of bounds")
            visitedActive.insert(index)
            traversalCount += 1

            // Check prev link for doubly-linked
            if N >= 2 {
                let prevIndex = unsafe _cachedPtr[index].links[1]
                if index == header.head {
                    assert(prevIndex == -1, "Head node must have prev == -1")
                } else {
                    assert(prevIndex == lastVisited, "Prev link inconsistent at index \(index)")
                }
            }

            lastVisited = index
            index = unsafe _cachedPtr[index].nextIndex
        }

        assert(traversalCount == header.count, "Traversal count \(traversalCount) != header.count \(header.count)")
        assert(lastVisited == header.tail, "Last visited \(lastVisited) != tail \(header.tail)")

        // Check tail's next link
        if header.tail >= 0 {
            let tailNext = unsafe _cachedPtr[header.tail].nextIndex
            assert(tailNext == -1, "Tail node must have next == -1, got \(tailNext)")
        }

        // Verify free list head is disjoint from active list
        if header.freeHead >= 0 {
            assert(!visitedActive.contains(header.freeHead), "Free list head overlaps with active list")
        }
        #endif
    }
}

// MARK: - Core Operations (~Copyable)

extension List.Linked.Bounded where Element: ~Copyable {

    /// Allocates a node slot, returning its index.
    ///
    /// Uses Model B allocation: freed slots from free-list first, then
    /// "virgin" slots via count (implicit nextUnused = count).
    @usableFromInline
    mutating func _allocateSlot() -> Int {
        if _storage.header.freeHead >= 0 {
            let index = _storage.header.freeHead
            // Load free-next from raw bytes (slot is deinitialized)
            _storage.header.freeHead = _storage._loadFreeNext(at: index)
            return index
        }
        return _storage.header.count
    }

    /// Adds an element to the front of the list.
    ///
    /// - Parameter element: The element to prepend.
    /// - Throws: ``Bounded/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1)
    @inlinable
    public mutating func prepend(_ element: consuming Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }

        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = _storage.header.head

        // Use cached pointer to avoid closure capture of consuming parameter
        unsafe (_cachedPtr + newIndex).initialize(
            to: List<Element>.Linked<N>.Node(element: element, links: links)
        )

        if _storage.header.head >= 0 && N >= 2 {
            unsafe (_cachedPtr[_storage.header.head].links[1] = newIndex)
        }

        if _storage.header.tail < 0 {
            _storage.header.tail = newIndex
        }

        _storage.header.head = newIndex
        _storage.header.count += 1
    }

    /// Adds an element to the back of the list.
    ///
    /// - Parameter element: The element to append.
    /// - Throws: ``Bounded/Error/overflow`` if the list is at capacity.
    /// - Complexity: O(1) (uses tail pointer for both N==1 and N==2)
    @inlinable
    public mutating func append(_ element: consuming Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }

        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1
        if N >= 2 {
            links[1] = _storage.header.tail
        }

        // Use cached pointer to avoid closure capture of consuming parameter
        unsafe (_cachedPtr + newIndex).initialize(
            to: List<Element>.Linked<N>.Node(element: element, links: links)
        )

        if _storage.header.tail >= 0 {
            unsafe (_cachedPtr[_storage.header.tail].links[0] = newIndex)
        }

        if _storage.header.head < 0 {
            _storage.header.head = newIndex
        }

        _storage.header.tail = newIndex
        _storage.header.count += 1
    }

    /// Removes and returns the first element, or `nil` if empty.
    ///
    /// - Returns: The first element, or `nil` if the list is empty.
    /// - Complexity: O(1)
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        guard _storage.header.count > 0 else { return nil }

        let headIndex = _storage.header.head

        // Step 1: Capture nextIndex BEFORE move (while Node is still initialized)
        let nextIndex = unsafe _cachedPtr[headIndex].links[0]

        // Step 2: Update header using captured values
        _storage.header.head = nextIndex
        if nextIndex < 0 {
            _storage.header.tail = -1
        }

        // Step 3: Patch neighbor (new head has no prev)
        if nextIndex >= 0 && N >= 2 {
            unsafe (_cachedPtr[nextIndex].links[1] = -1)
        }

        // Step 4: Move element out (deinitializes the node)
        let node = unsafe (_cachedPtr + headIndex).move()

        // Step 5: Store free-next as raw bytes and update freeHead
        _storage._storeFreeNext(at: headIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = headIndex

        _storage.header.count -= 1
        return node.element
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
        guard _storage.header.count > 0 else { return nil }

        let tailIndex = _storage.header.tail

        // Step 1: Capture prevIndex BEFORE move (while Node is still initialized)
        let prevIndex = unsafe _cachedPtr[tailIndex].links[1]

        // Step 2: Update header using captured values
        _storage.header.tail = prevIndex
        if prevIndex < 0 {
            _storage.header.head = -1
        }

        // Step 3: Patch neighbor (new tail has no next)
        if prevIndex >= 0 {
            unsafe (_cachedPtr[prevIndex].links[0] = -1)
        }

        // Step 4: Move element out (deinitializes the node)
        let node = unsafe (_cachedPtr + tailIndex).move()

        // Step 5: Store free-next as raw bytes and update freeHead
        _storage._storeFreeNext(at: tailIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = tailIndex

        _storage.header.count -= 1
        return node.element
    }

    @usableFromInline
    mutating func _popLastSingly() -> Element? {
        guard _storage.header.count > 0 else { return nil }

        let tailIndex = _storage.header.tail

        // Step 1: Find prev node (O(n) traversal) - BEFORE any move
        var prevIndex: Int = -1
        if _storage.header.count > 1 {
            var current = _storage.header.head
            while current >= 0 {
                let next = unsafe _cachedPtr[current].links[0]
                if next == tailIndex {
                    prevIndex = current
                    break
                }
                current = next
            }
        }

        // Step 2: Update header using captured values
        _storage.header.tail = prevIndex
        if prevIndex < 0 {
            _storage.header.head = -1
        }

        // Step 3: Patch neighbor (new tail has no next)
        if prevIndex >= 0 {
            unsafe (_cachedPtr[prevIndex].links[0] = -1)
        }

        // Step 4: Move element out (deinitializes the node)
        let node = unsafe (_cachedPtr + tailIndex).move()

        // Step 5: Store free-next as raw bytes and update freeHead
        _storage._storeFreeNext(at: tailIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = tailIndex

        _storage.header.count -= 1
        return node.element
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
        guard _storage.header.count > 0 else { return }

        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            while index >= 0 {
                let nextIndex = unsafe nodes[index].nextIndex
                unsafe (nodes + index).deinitialize(count: 1)
                index = nextIndex
            }
        }

        _storage.header.head = -1
        _storage.header.tail = -1
        _storage.header.freeHead = -1
        _storage.header.count = 0
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension List.Linked.Bounded where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
            unsafe (_cachedPtr = _storage._nodesPointer)
        }
    }

    /// Adds an element to the front of the list (CoW-aware).
    @inlinable
    public mutating func prepend(_ element: Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        makeUnique()

        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = _storage.header.head

        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + newIndex).initialize(
                to: List<Element>.Linked<N>.Node(element: element, links: links)
            )

            if _storage.header.head >= 0 && N >= 2 {
                unsafe (nodes[_storage.header.head].links[1] = newIndex)
            }
        }

        if _storage.header.tail < 0 {
            _storage.header.tail = newIndex
        }

        _storage.header.head = newIndex
        _storage.header.count += 1
    }

    /// Adds an element to the back of the list (CoW-aware).
    @inlinable
    public mutating func append(_ element: Element) throws(__ListLinkedBoundedError) {
        guard !isFull else { throw .overflow }
        makeUnique()

        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1
        if N >= 2 {
            links[1] = _storage.header.tail
        }

        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + newIndex).initialize(
                to: List<Element>.Linked<N>.Node(element: element, links: links)
            )

            if _storage.header.tail >= 0 {
                unsafe (nodes[_storage.header.tail].links[0] = newIndex)
            }
        }

        if _storage.header.head < 0 {
            _storage.header.head = newIndex
        }

        _storage.header.tail = newIndex
        _storage.header.count += 1
    }

    /// Removes and returns the first element (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func popFirst() -> Element? {
        makeUnique()
        guard _storage.header.count > 0 else { return nil }

        let headIndex = _storage.header.head

        // Step 1: Capture element and indices BEFORE deinitialize
        var element: Element?
        var nextIndex: Int = -1
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            element = unsafe nodes[headIndex].element
            nextIndex = unsafe nodes[headIndex].nextIndex
        }

        // Step 2: Update header using captured values
        _storage.header.head = nextIndex
        if nextIndex < 0 {
            _storage.header.tail = -1
        }

        // Step 3: Patch neighbor (new head has no prev)
        if nextIndex >= 0 && N >= 2 {
            _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                unsafe (nodes[nextIndex].links[1] = -1)
            }
        }

        // Step 4: Deinitialize the node
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + headIndex).deinitialize(count: 1)
        }

        // Step 5: Store free-next as raw bytes and update freeHead
        _storage._storeFreeNext(at: headIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = headIndex

        _storage.header.count -= 1
        return element
    }

    /// Removes and returns the last element (CoW-aware).
    @inlinable
    @discardableResult
    public mutating func popLast() -> Element? {
        makeUnique()
        if N >= 2 {
            return _popLastDoublyCopyable()
        } else {
            return _popLastSinglyCopyable()
        }
    }

    @usableFromInline
    mutating func _popLastDoublyCopyable() -> Element? {
        guard _storage.header.count > 0 else { return nil }

        let tailIndex = _storage.header.tail

        // Step 1: Capture element and indices BEFORE deinitialize
        var element: Element?
        var prevIndex: Int = -1
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            prevIndex = unsafe nodes[tailIndex].links[1]
            element = unsafe nodes[tailIndex].element
        }

        // Step 2: Update header using captured values
        _storage.header.tail = prevIndex
        if prevIndex < 0 {
            _storage.header.head = -1
        }

        // Step 3: Patch neighbor (new tail has no next)
        if prevIndex >= 0 {
            _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                unsafe (nodes[prevIndex].links[0] = -1)
            }
        }

        // Step 4: Deinitialize the node
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + tailIndex).deinitialize(count: 1)
        }

        // Step 5: Store free-next as raw bytes and update freeHead
        _storage._storeFreeNext(at: tailIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = tailIndex

        _storage.header.count -= 1
        return element
    }

    @usableFromInline
    mutating func _popLastSinglyCopyable() -> Element? {
        guard _storage.header.count > 0 else { return nil }

        let tailIndex = _storage.header.tail

        // Step 1: Find prev and capture element BEFORE deinitialize
        var prevIndex: Int = -1
        if _storage.header.count > 1 {
            var current = _storage.header.head
            _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
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
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            element = unsafe nodes[tailIndex].element
        }

        // Step 2: Update header using captured values
        _storage.header.tail = prevIndex
        if prevIndex < 0 {
            _storage.header.head = -1
        }

        // Step 3: Patch neighbor (new tail has no next)
        if prevIndex >= 0 {
            _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                unsafe (nodes[prevIndex].links[0] = -1)
            }
        }

        // Step 4: Deinitialize the node
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + tailIndex).deinitialize(count: 1)
        }

        // Step 5: Store free-next as raw bytes and update freeHead
        _storage._storeFreeNext(at: tailIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = tailIndex

        _storage.header.count -= 1
        return element
    }

    /// Removes all elements (CoW-aware).
    @inlinable
    public mutating func clear() {
        makeUnique()
        guard _storage.header.count > 0 else { return }

        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            while index >= 0 {
                let nextIndex = unsafe nodes[index].nextIndex
                unsafe (nodes + index).deinitialize(count: 1)
                index = nextIndex
            }
        }

        _storage.header.head = -1
        _storage.header.tail = -1
        _storage.header.freeHead = -1
        _storage.header.count = 0
    }
}

// MARK: - Peek

extension List.Linked.Bounded where Element: ~Copyable {
    /// Provides peek access to elements without removing them.
    ///
    /// Use `peek.first` or `peek.last` to access elements via borrowing closures.
    @inlinable
    public var peek: Peek {
        Peek(_storage: _storage)
    }
}

extension List.Linked.Bounded where Element: ~Copyable {
    /// A view for peeking at elements without removing them.
    public struct Peek {
        @usableFromInline
        let _storage: List<Element>.Linked<N>.Storage

        @usableFromInline
        init(_storage: List<Element>.Linked<N>.Storage) {
            self._storage = _storage
        }

        /// Peeks at the first element without removing it.
        @inlinable
        public func first<R>(_ body: (borrowing Element) -> R) -> R? {
            guard _storage.header.count > 0 else { return nil }
            let headIndex = _storage.header.head
            return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                body(unsafe nodes[headIndex].element)
            }
        }

        /// Peeks at the last element without removing it.
        @inlinable
        public func last<R>(_ body: (borrowing Element) -> R) -> R? {
            guard _storage.header.count > 0 else { return nil }
            let tailIndex = _storage.header.tail
            return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                body(unsafe nodes[tailIndex].element)
            }
        }
    }
}

extension List.Linked.Bounded {
    /// Returns the first element, or `nil` if empty.
    @inlinable
    public var first: Element? {
        guard _storage.header.count > 0 else { return nil }
        let headIndex = _storage.header.head
        return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[headIndex].element
        }
    }

    /// Returns the last element, or `nil` if empty.
    @inlinable
    public var last: Element? {
        guard _storage.header.count > 0 else { return nil }
        let tailIndex = _storage.header.tail
        return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[tailIndex].element
        }
    }
}

// MARK: - ForEach

extension List.Linked.Bounded where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    @inlinable
    public func forEach(_ body: (borrowing Element) -> Void) {
        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            while index >= 0 {
                body(unsafe nodes[index].element)
                index = unsafe nodes[index].nextIndex
            }
        }
    }

    /// Provides a reversed view of the list for iteration.
    ///
    /// - Precondition: N >= 2 (doubly-linked)
    @inlinable
    public var reversed: Reversed {
        precondition(N >= 2, "reversed requires N >= 2 (doubly-linked)")
        return Reversed(_storage: _storage)
    }
}

extension List.Linked.Bounded where Element: ~Copyable {
    /// A reversed view of the bounded linked list for back-to-front iteration.
    public struct Reversed {
        @usableFromInline
        let _storage: List<Element>.Linked<N>.Storage

        @usableFromInline
        init(_storage: List<Element>.Linked<N>.Storage) {
            self._storage = _storage
        }

        /// Calls the given closure for each element, back to front.
        @inlinable
        public func forEach(_ body: (borrowing Element) -> Void) {
            var index = _storage.header.tail
            _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                while index >= 0 {
                    body(unsafe nodes[index].element)
                    index = unsafe nodes[index].links[1]
                }
            }
        }
    }
}

// MARK: - Sequence (Copyable elements only)

extension List.Linked.Bounded: Sequence where Element: Copyable {
    /// An iterator over the elements of a bounded linked list.
    public struct Iterator: IteratorProtocol {
        @usableFromInline
        let _storage: List<Element>.Linked<N>.Storage

        @usableFromInline
        var _current: Int

        @usableFromInline
        init(storage: List<Element>.Linked<N>.Storage) {
            self._storage = storage
            self._current = storage.header.head
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _current >= 0 else { return nil }
            return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                let element = unsafe nodes[_current].element
                _current = unsafe nodes[_current].nextIndex
                return element
            }
        }
    }

    @inlinable
    public func makeIterator() -> Iterator {
        Iterator(storage: _storage)
    }
}

// MARK: - Equatable

extension List.Linked.Bounded: Equatable where Element: Equatable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }

        var lhsIndex = lhs._storage.header.head
        var rhsIndex = rhs._storage.header.head

        while lhsIndex >= 0 && rhsIndex >= 0 {
            let lhsElement = unsafe lhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[lhsIndex].element
            }
            let rhsElement = unsafe rhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[rhsIndex].element
            }

            if lhsElement != rhsElement { return false }

            lhsIndex = unsafe lhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[lhsIndex].nextIndex
            }
            rhsIndex = unsafe rhs._storage.withUnsafeMutablePointerToElements { nodes in
                unsafe nodes[rhsIndex].nextIndex
            }
        }

        return true
    }
}

// MARK: - Hashable

extension List.Linked.Bounded: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage.header.count)
        forEach { hasher.combine($0) }
    }
}
