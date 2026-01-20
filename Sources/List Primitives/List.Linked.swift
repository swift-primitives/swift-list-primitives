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

extension List where Element: ~Copyable {

    /// A linked list with N links per node.
    ///
    /// `Linked<N>` is the canonical linked list type where N specifies the number
    /// of links per node:
    ///
    /// - `Linked<1>`: Singly-linked (forward link only)
    /// - `Linked<2>`: Doubly-linked (forward + backward links)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Singly-linked list (with tail pointer)
    /// var singly = List<Int>.Linked<1>()
    /// singly.prepend(1)     // O(1)
    /// singly.append(2)      // O(1) - uses tail pointer
    /// singly.popFirst()     // O(1)
    /// singly.popLast()      // O(n) - must traverse to find prev
    ///
    /// // Doubly-linked list
    /// var doubly = List<Int>.Linked<2>()
    /// doubly.prepend(1)     // O(1)
    /// doubly.append(2)      // O(1)
    /// doubly.popFirst()     // O(1)
    /// doubly.popLast()      // O(1)
    /// ```
    ///
    /// ## Variants
    ///
    /// - ``Linked``: Dynamically-growing with amortized O(1) operations (this type)
    /// - ``Linked/Bounded``: Fixed-capacity, throws on overflow
    /// - ``Linked/Inline``: Zero-allocation inline storage with compile-time capacity
    /// - ``Linked/Small``: Inline storage with automatic spill to heap
    ///
    /// ## Arena-Based Storage
    ///
    /// Uses arena-based storage where all nodes are stored contiguously. Nodes
    /// reference each other by index rather than pointer, improving cache locality.
    ///
    /// ## Move-Only Support
    ///
    /// Both the list and its elements can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var handles = List<FileHandle>.Linked<2>()
    /// handles.prepend(FileHandle())
    /// ```
    ///
    /// ## Copy-on-Write
    ///
    /// When `Element` is `Copyable`, `Linked` uses copy-on-write semantics:
    /// copies share storage until mutation.
    @safe
    public struct Linked<let N: Int>: ~Copyable {

        // MARK: - Header

        /// Header for arena-based linked list storage.
        @usableFromInline
        struct Header {
            /// Index of first element (-1 if empty).
            @usableFromInline var head: Int
            /// Index of last element (-1 if empty).
            @usableFromInline var tail: Int
            /// Index of first free slot (-1 if none).
            @usableFromInline var freeHead: Int
            /// Number of active elements.
            @usableFromInline var count: Int
            /// Total node capacity.
            @usableFromInline var capacity: Int

            @usableFromInline
            init() {
                self.head = -1
                self.tail = -1
                self.freeHead = -1
                self.count = 0
                self.capacity = 0
            }
        }

        // MARK: - Node

        /// A node in the arena-based linked list.
        ///
        /// Links are stored in an `InlineArray<N, Int>` where:
        /// - `links[0]` = nextIndex (always present)
        /// - `links[1]` = prevIndex (when N >= 2)
        @usableFromInline
        struct Node: ~Copyable {
            /// The element stored in this node.
            @usableFromInline var element: Element
            /// Links to other nodes. Index 0 is next, index 1 is prev (if N >= 2).
            @usableFromInline var links: InlineArray<N, Int>

            @usableFromInline
            init(element: consuming Element, links: InlineArray<N, Int>) {
                self.element = element
                self.links = links
            }

            /// The next node index (-1 for none/tail).
            @usableFromInline
            var nextIndex: Int {
                get { links[0] }
                set { links[0] = newValue }
            }

            /// The previous node index (-1 for none/head). Only valid when N >= 2.
            @usableFromInline
            var prevIndex: Int {
                get {
                    precondition(N >= 2, "prevIndex requires N >= 2")
                    return links[1]
                }
                set {
                    precondition(N >= 2, "prevIndex requires N >= 2")
                    links[1] = newValue
                }
            }
        }

        // MARK: - Storage

        /// Internal storage class for arena-based linked list.
        ///
        /// Uses `ManagedBuffer` for efficient single-allocation storage.
        /// Declared as a nested class so that `Element` inherits the `~Copyable`
        /// suppression from the outer type.
        @usableFromInline
        final class Storage: ManagedBuffer<Header, Node> {

            @usableFromInline
            static func create() -> Storage {
                let storage = Storage.create(minimumCapacity: 0) { _ in Header() }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            @usableFromInline
            static func create(minimumCapacity: Int) -> Storage {
                var header = Header()
                header.capacity = minimumCapacity
                let storage = Storage.create(minimumCapacity: minimumCapacity) { _ in header }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            deinit {
                let count = header.count
                guard count > 0 else { return }
                var index = header.head
                _ = unsafe withUnsafeMutablePointerToElements { nodes in
                    while index >= 0 {
                        let nextIndex = unsafe nodes[index].nextIndex
                        unsafe (nodes + index).deinitialize(count: 1)
                        index = nextIndex
                    }
                }
            }

            @usableFromInline
            var _nodesPointer: UnsafeMutablePointer<Node> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }

            /// Initializes a node at the given index.
            @usableFromInline
            func _initializeNode(at index: Int, element: consuming Element, links: InlineArray<N, Int>) {
                let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
                unsafe ptr.initialize(to: Node(element: element, links: links))
            }

            /// Deinitializes the node at the given index.
            @usableFromInline
            func _deinitializeNode(at index: Int) {
                let ptr = unsafe _nodesPointer + index
                unsafe ptr.deinitialize(count: 1)
            }

            // MARK: - Free-List Raw Byte Helpers
            //
            // After a node is moved/deinitialized, its memory is uninitialized.
            // We store the free-list "next" pointer as raw bytes in that slot.
            // These helpers MUST only be called when the slot is known to be free
            // (after move/deinit, or before first initialization).

            /// Loads the free-list next index from a freed slot.
            ///
            /// - Precondition: The slot at `index` must be deinitialized/free.
            @usableFromInline
            func _loadFreeNext(at index: Int) -> Int {
                unsafe withUnsafeMutablePointerToElements { ptr in
                    unsafe UnsafeRawPointer(ptr.advanced(by: index)).load(as: Int.self)
                }
            }

            /// Stores the free-list next index into a freed slot.
            ///
            /// - Precondition: The slot at `index` must be deinitialized/free.
            @usableFromInline
            func _storeFreeNext(at index: Int, next: Int) {
                unsafe withUnsafeMutablePointerToElements { ptr in
                    unsafe UnsafeMutableRawPointer(ptr.advanced(by: index)).storeBytes(of: next, as: Int.self)
                }
            }

            /// Moves all elements to new storage, linearizing the list.
            ///
            /// After this call, `self` is in an empty state (header reset) so that
            /// `deinit` won't double-destroy the moved elements.
            @usableFromInline
            func _moveAllElements(to newStorage: Storage) {
                let count = header.count
                guard count > 0 else { return }

                var srcIndex = header.head
                var dstIndex = 0
                _ = unsafe withUnsafeMutablePointerToElements { src in
                    unsafe newStorage.withUnsafeMutablePointerToElements { dst in
                        while srcIndex >= 0 {
                            // Capture next BEFORE move (while Node is still initialized)
                            let nextSrcIndex = unsafe src[srcIndex].nextIndex

                            // Create new links for linearized storage
                            var newLinks = InlineArray<N, Int>(repeating: -1)
                            newLinks[0] = dstIndex + 1 < count ? dstIndex + 1 : -1  // next
                            if N >= 2 {
                                newLinks[1] = dstIndex > 0 ? dstIndex - 1 : -1  // prev
                            }

                            // Move element to new storage (deinitializes old)
                            unsafe (dst + dstIndex).initialize(
                                to: Node(element: (src + srcIndex).move().element, links: newLinks)
                            )

                            // Advance using captured value
                            srcIndex = nextSrcIndex
                            dstIndex += 1
                        }
                    }
                }

                // Reset old header so deinit doesn't traverse moved nodes
                // Model B: freeHead = -1 (no freed slots after linearization)
                header.head = -1
                header.tail = -1
                header.freeHead = -1
                header.count = 0
            }
        }

        @usableFromInline
        var _storage: Storage

        // MARK: - Variants (declared here for ~Copyable propagation)

        /// A fixed-capacity linked list.
        ///
        /// `Linked.Bounded` allocates storage upfront and throws on overflow.
        /// Use this variant when capacity is known or in contexts requiring
        /// predictable memory behavior (embedded, real-time).
        ///
        /// ## Example
        ///
        /// ```swift
        /// var list = try List<Int>.Linked<2>.Bounded(capacity: 10)
        /// try list.prepend(1)
        /// try list.append(2)
        /// list.popFirst()  // Optional(1)
        /// ```
        @safe
        public struct Bounded: ~Copyable {
            @usableFromInline
            var _storage: Storage

            /// Cached pointer to node storage.
            @usableFromInline
            var _cachedPtr: UnsafeMutablePointer<Node>

            /// The maximum number of elements the list can hold.
            public let capacity: Int

            /// Creates a list with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of elements. Must be non-negative.
            /// - Throws: ``Bounded/Error/invalidCapacity`` if capacity is negative.
            @inlinable
            public init(capacity: Int) throws(__ListLinkedBoundedError) {
                guard capacity >= 0 else {
                    throw .invalidCapacity
                }

                self._storage = Storage.create(minimumCapacity: capacity)
                unsafe (self._cachedPtr = _storage._nodesPointer)
                self.capacity = capacity
            }
        }

        // Note: Inline and Small variants require Copyable elements due to InlineArray
        // limitations. They are declared in an extension below.

        // MARK: - Init

        /// Creates an empty linked list.
        ///
        /// No allocation occurs until the first element is added.
        @inlinable
        public init() {
            precondition(N >= 1 && N <= 2, "Linked<N> requires N in 1...2")
            self._storage = Storage.create()
        }

        /// Creates a list with reserved capacity.
        ///
        /// Pre-allocates storage for the specified number of elements.
        ///
        /// - Parameter capacity: Number of elements to reserve space for. Must be non-negative.
        /// - Throws: ``Linked/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(reservingCapacity capacity: Int) throws(List<Element>.Linked<N>.Error) {
            precondition(N >= 1 && N <= 2, "Linked<N> requires N in 1...2")
            guard capacity >= 0 else {
                throw .invalidCapacity
            }

            if capacity == 0 {
                self._storage = Storage.create()
            } else {
                self._storage = Storage.create(minimumCapacity: capacity)
            }
        }
    }
}

// MARK: - Conditional Copyable

/// `List.Linked` is `Copyable` when its elements are `Copyable`.
extension List.Linked: Copyable where Element: Copyable {}

/// `List.Linked.Bounded` is `Copyable` when its elements are `Copyable`.
extension List.Linked.Bounded: Copyable where Element: Copyable {}

// Note: List.Linked.Inline and List.Linked.Small are UNCONDITIONALLY ~Copyable due to deinit

// MARK: - Inline and Small Variants (Copyable elements only)
//
// These variants use InlineArray which requires Copyable elements.
// Per [MEM-COPY-006] Category 4, there is no workaround for this limitation.

extension List.Linked where Element: Copyable {

    /// A fixed-capacity, inline-storage linked list with compile-time capacity.
    ///
    /// `Linked.Inline` stores elements directly within the struct's memory layout,
    /// requiring no heap allocation. The capacity is specified as a compile-time
    /// generic parameter.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var list = List<Int>.Linked<2>.Inline<8>()
    /// try list.prepend(1)
    /// try list.append(2)
    /// ```
    ///
    /// ## Non-Copyable Container
    ///
    /// `Inline` is unconditionally `~Copyable` (move-only) even though it requires
    /// `Copyable` elements. This is because it contains inline storage that requires
    /// careful lifecycle management.
    ///
    /// ## Element Requirement
    ///
    /// This variant requires `Element: Copyable` due to InlineArray limitations.
    /// For ~Copyable elements, use ``Linked`` or ``Bounded`` instead.
    public struct Inline<let capacity: Int>: ~Copyable {
        /// Storage for elements. Each slot is either a valid element or nil.
        @usableFromInline
        var _elements: InlineArray<capacity, Element?>

        /// Storage for links. Each slot stores [next, prev?] indices.
        @usableFromInline
        var _links: InlineArray<capacity, InlineArray<N, Int>>

        /// Index of first element (-1 if empty).
        @usableFromInline
        var _head: Int

        /// Index of last element (-1 if empty).
        @usableFromInline
        var _tail: Int

        /// Index of first free slot (-1 if none).
        @usableFromInline
        var _freeHead: Int

        /// Current element count.
        @usableFromInline
        var _count: Int

        /// Creates an empty inline list.
        @inlinable
        public init() {
            precondition(N >= 1 && N <= 2, "Linked<N> requires N in 1...2")
            self._elements = InlineArray(repeating: nil)
            self._links = InlineArray(repeating: InlineArray(repeating: -1))
            self._head = -1
            self._tail = -1
            self._freeHead = -1
            self._count = 0
        }

        // Note: No deinit needed - InlineArray of optionals cleans up automatically
    }

    /// A linked list with small-buffer optimization (SmallVec pattern).
    ///
    /// `Linked.Small` stores up to `inlineCapacity` elements in inline storage,
    /// then automatically spills to heap storage when that capacity is exceeded.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var list = List<Int>.Linked<2>.Small<4>()  // Inline up to 4 elements
    /// list.prepend(1)  // Inline
    /// list.prepend(2)  // Inline
    /// list.prepend(3)  // Inline
    /// list.prepend(4)  // Inline
    /// list.prepend(5)  // Spills to heap
    /// ```
    ///
    /// ## Non-Copyable Container
    ///
    /// `Small` is unconditionally `~Copyable` (move-only) even though it requires
    /// `Copyable` elements. This is because it contains inline storage that requires
    /// careful lifecycle management.
    ///
    /// ## Element Requirement
    ///
    /// This variant requires `Element: Copyable` due to InlineArray limitations.
    /// For ~Copyable elements, use ``Linked`` or ``Bounded`` instead.
    @safe
    public struct Small<let inlineCapacity: Int>: ~Copyable {
        /// Storage for inline elements.
        @usableFromInline
        var _inlineElements: InlineArray<inlineCapacity, Element?>

        /// Storage for inline links.
        @usableFromInline
        var _inlineLinks: InlineArray<inlineCapacity, InlineArray<N, Int>>

        /// Index of first element (-1 if empty).
        @usableFromInline
        var _head: Int

        /// Index of last element (-1 if empty).
        @usableFromInline
        var _tail: Int

        /// Index of first free slot (-1 if none, only for inline mode).
        @usableFromInline
        var _freeHead: Int

        /// Current element count.
        @usableFromInline
        var _count: Int

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        var _heap: Storage?

        /// Creates an empty small list.
        @inlinable
        public init() {
            precondition(N >= 1 && N <= 2, "Linked<N> requires N in 1...2")
            self._inlineElements = InlineArray(repeating: nil)
            self._inlineLinks = InlineArray(repeating: InlineArray(repeating: -1))
            self._head = -1
            self._tail = -1
            self._freeHead = -1
            self._count = 0
            self._heap = nil
        }

        // Note: No deinit needed - InlineArray and Storage clean up automatically

        /// Whether the list is currently using heap storage.
        @inlinable
        public var isSpilled: Bool { _heap != nil }
    }
}

// MARK: - Properties

extension List.Linked where Element: ~Copyable {
    /// The current number of elements in the list.
    @inlinable
    public var count: Int { _storage.header.count }

    /// Whether the list is empty.
    @inlinable
    public var isEmpty: Bool { _storage.header.count == 0 }

    /// The current capacity of the list.
    @inlinable
    public var capacity: Int { _storage.capacity }
}

// MARK: - Capacity Management

extension List.Linked where Element: ~Copyable {
    /// Ensures the list has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Int) {
        guard _storage.capacity < minimumCapacity else { return }

        let newCapacity = Swift.max(minimumCapacity, _storage.capacity * 2, 4)
        let newStorage = Storage.create(minimumCapacity: newCapacity)
        let currentCount = _storage.header.count

        _storage._moveAllElements(to: newStorage)
        newStorage.header.head = currentCount > 0 ? 0 : -1
        newStorage.header.tail = currentCount > 0 ? currentCount - 1 : -1
        newStorage.header.count = currentCount
        _storage = newStorage
    }

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

    /// Reserves capacity for at least the specified number of elements.
    ///
    /// Use this method to avoid multiple reallocations when adding a known
    /// number of elements.
    ///
    /// - Parameter minimumCapacity: The minimum total capacity to reserve.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Int) {
        ensureCapacity(minimumCapacity)
    }

    // MARK: - Invariant Checking (Debug Only)

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

        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            var index = header.head
            while index >= 0 {
                assert(!visitedActive.contains(index), "Cycle detected in active list at index \(index)")
                assert(index < _storage.capacity, "Index \(index) out of bounds")
                visitedActive.insert(index)
                traversalCount += 1

                // Check prev link for doubly-linked
                if N >= 2 {
                    let prevIndex = unsafe nodes[index].links[1]
                    if index == header.head {
                        assert(prevIndex == -1, "Head node must have prev == -1")
                    } else {
                        assert(prevIndex == lastVisited, "Prev link inconsistent at index \(index)")
                    }
                }

                lastVisited = index
                index = unsafe nodes[index].nextIndex
            }
        }

        assert(traversalCount == header.count, "Traversal count \(traversalCount) != header.count \(header.count)")
        assert(lastVisited == header.tail, "Last visited \(lastVisited) != tail \(header.tail)")

        // Check tail's next link
        if header.tail >= 0 {
            _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                let tailNext = unsafe nodes[header.tail].nextIndex
                assert(tailNext == -1, "Tail node must have next == -1, got \(tailNext)")
            }
        }

        // Verify free list is disjoint from active list
        // Note: We can only check that free list indices don't overlap with active indices
        // We cannot traverse the free list safely (it's raw bytes), but we can check freeHead
        if header.freeHead >= 0 {
            assert(!visitedActive.contains(header.freeHead), "Free list head overlaps with active list")
        }
        #endif
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
        ensureCapacity(_storage.header.count + 1)
        let newIndex = _allocateSlot()

        // Create links: next = old head, prev = -1 (if N >= 2)
        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = _storage.header.head  // next = old head

        // Use cached pointer to avoid closure capture of consuming parameter
        let nodes = unsafe _storage._nodesPointer
        unsafe (nodes + newIndex).initialize(to: Node(element: element, links: links))

        // Update old head's prev link (if doubly-linked)
        if _storage.header.head >= 0 && N >= 2 {
            unsafe (nodes[_storage.header.head].links[1] = newIndex)
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
    /// - Complexity: O(1) amortized (uses tail pointer for both N==1 and N==2)
    @inlinable
    public mutating func append(_ element: consuming Element) {
        if N >= 2 {
            _appendDoubly(element)
        } else {
            _appendSingly(element)
        }
    }

    /// Appends for doubly-linked list (O(1)).
    @usableFromInline
    mutating func _appendDoubly(_ element: consuming Element) {
        ensureCapacity(_storage.header.count + 1)
        let newIndex = _allocateSlot()

        // Create links: next = -1, prev = old tail
        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1  // next = none (new tail)
        if N >= 2 {
            links[1] = _storage.header.tail  // prev = old tail
        }

        // Use cached pointer to avoid closure capture of consuming parameter
        let nodes = unsafe _storage._nodesPointer
        unsafe (nodes + newIndex).initialize(to: Node(element: element, links: links))

        // Update old tail's next link
        if _storage.header.tail >= 0 {
            unsafe (nodes[_storage.header.tail].links[0] = newIndex)
        }

        if _storage.header.head < 0 {
            _storage.header.head = newIndex
        }

        _storage.header.tail = newIndex
        _storage.header.count += 1
    }

    /// Appends for singly-linked list (O(1) - uses tail pointer).
    @usableFromInline
    mutating func _appendSingly(_ element: consuming Element) {
        ensureCapacity(_storage.header.count + 1)
        let newIndex = _allocateSlot()

        // Create links: next = -1
        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1  // next = none (new tail)

        // Use cached pointer to avoid closure capture of consuming parameter
        let nodes = unsafe _storage._nodesPointer
        unsafe (nodes + newIndex).initialize(to: Node(element: element, links: links))

        // Update old tail's next link
        if _storage.header.tail >= 0 {
            unsafe (nodes[_storage.header.tail].links[0] = newIndex)
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

        // Step 1: Capture indices BEFORE move (while Node is still initialized)
        let nextIndex: Int = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[headIndex].nextIndex
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

        // Step 4: Move element out (deinitializes the node)
        let element: Element = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + headIndex).move().element
        }

        // Step 5: Store free-next as raw bytes (slot is now deinitialized)
        _storage._storeFreeNext(at: headIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = headIndex

        _storage.header.count -= 1
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

    /// Pop last for doubly-linked list (O(1)).
    @usableFromInline
    mutating func _popLastDoubly() -> Element? {
        guard _storage.header.count > 0 else { return nil }

        let tailIndex = _storage.header.tail

        // Step 1: Capture indices BEFORE move (while Node is still initialized)
        let prevIndex: Int = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[tailIndex].links[1]  // prev link
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

        // Step 4: Move element out (deinitializes the node)
        let element: Element = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + tailIndex).move().element
        }

        // Step 5: Store free-next as raw bytes (slot is now deinitialized)
        _storage._storeFreeNext(at: tailIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = tailIndex

        _storage.header.count -= 1
        return element
    }

    /// Pop last for singly-linked list (O(n) - must traverse to find prev).
    @usableFromInline
    mutating func _popLastSingly() -> Element? {
        guard _storage.header.count > 0 else { return nil }

        let tailIndex = _storage.header.tail

        // Step 1: Find the node before tail (O(n) traversal) - BEFORE any move
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

        // Step 4: Move element out (deinitializes the node)
        let element: Element = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + tailIndex).move().element
        }

        // Step 5: Store free-next as raw bytes (slot is now deinitialized)
        _storage._storeFreeNext(at: tailIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = tailIndex

        _storage.header.count -= 1
        return element
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
        guard _storage.header.count > 0 else { return }

        // Deinitialize all nodes
        var index = _storage.header.head
        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            while index >= 0 {
                let nextIndex = unsafe nodes[index].nextIndex
                unsafe (nodes + index).deinitialize(count: 1)
                index = nextIndex
            }
        }

        if keepingCapacity {
            _storage.header.head = -1
            _storage.header.tail = -1
            _storage.header.freeHead = -1
            _storage.header.count = 0
        } else {
            _storage = Storage.create()
        }
    }
}

// MARK: - Copy-on-Write (Copyable elements only)

extension List.Linked where Element: Copyable {
    /// Ensures the storage is uniquely referenced before mutation.
    @usableFromInline
    mutating func makeUnique() {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _storage.copy()
        }
    }

    /// Adds an element to the front of the list (CoW-aware).
    ///
    /// - Parameter element: The element to prepend.
    /// - Complexity: O(1) amortized, O(n) if copy triggered
    @inlinable
    public mutating func prepend(_ element: Element) {
        makeUnique()
        ensureCapacity(_storage.header.count + 1)
        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = _storage.header.head

        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + newIndex).initialize(to: Node(element: element, links: links))

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
    ///
    /// - Parameter element: The element to append.
    /// - Complexity: O(1) amortized; +O(n) if copy triggered
    @inlinable
    public mutating func append(_ element: Element) {
        makeUnique()
        if N >= 2 {
            _appendDoublyCopyable(element)
        } else {
            _appendSinglyCopyable(element)
        }
    }

    @usableFromInline
    mutating func _appendDoublyCopyable(_ element: Element) {
        ensureCapacity(_storage.header.count + 1)
        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1
        if N >= 2 {
            links[1] = _storage.header.tail
        }

        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + newIndex).initialize(to: Node(element: element, links: links))

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

    @usableFromInline
    mutating func _appendSinglyCopyable(_ element: Element) {
        ensureCapacity(_storage.header.count + 1)
        let newIndex = _allocateSlot()

        var links = InlineArray<N, Int>(repeating: -1)
        links[0] = -1

        _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe (nodes + newIndex).initialize(to: Node(element: element, links: links))

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

        // Step 5: Store free-next as raw bytes (slot is now deinitialized)
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

        // Step 5: Store free-next as raw bytes (slot is now deinitialized)
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

        // Step 5: Store free-next as raw bytes (slot is now deinitialized)
        _storage._storeFreeNext(at: tailIndex, next: _storage.header.freeHead)
        _storage.header.freeHead = tailIndex

        _storage.header.count -= 1
        return element
    }

    /// Removes all elements (CoW-aware).
    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
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

        if keepingCapacity {
            _storage.header.head = -1
            _storage.header.tail = -1
            _storage.header.freeHead = -1
            _storage.header.count = 0
        } else {
            _storage = Storage.create()
        }
    }
}

// MARK: - Storage Copy Helper (Copyable elements)

extension List.Linked.Storage where Element: Copyable {
    /// Creates a copy of this storage with all elements duplicated and linearized.
    @usableFromInline
    func copy() -> List<Element>.Linked<N>.Storage {
        let count = header.count
        guard count > 0 else {
            return List<Element>.Linked<N>.Storage.create()
        }

        let new = List<Element>.Linked<N>.Storage.create(minimumCapacity: capacity)
        new.header.head = 0
        new.header.tail = count - 1
        new.header.count = count

        var srcIndex = header.head
        var dstIndex = 0
        _ = unsafe withUnsafeMutablePointerToElements { src in
            unsafe new.withUnsafeMutablePointerToElements { dst in
                while srcIndex >= 0 {
                    var newLinks = InlineArray<N, Int>(repeating: -1)
                    newLinks[0] = dstIndex + 1 < count ? dstIndex + 1 : -1
                    if N >= 2 {
                        newLinks[1] = dstIndex > 0 ? dstIndex - 1 : -1
                    }
                    unsafe (dst + dstIndex).initialize(
                        to: List<Element>.Linked<N>.Node(
                            element: src[srcIndex].element,
                            links: newLinks
                        )
                    )
                    srcIndex = unsafe src[srcIndex].nextIndex
                    dstIndex += 1
                }
            }
        }

        return new
    }
}

// MARK: - Peek

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
    @inlinable
    public var peek: Peek {
        Peek(_storage: _storage)
    }
}

extension List.Linked where Element: ~Copyable {
    /// A view for peeking at elements without removing them.
    ///
    /// Access via the ``List/Linked/peek`` property.
    public struct Peek {
        @usableFromInline
        let _storage: Storage

        @usableFromInline
        init(_storage: Storage) {
            self._storage = _storage
        }

        /// Peeks at the first element without removing it.
        ///
        /// Uses a closure to support `~Copyable` elements via borrowing.
        ///
        /// - Parameter body: A closure that receives a borrowed reference to the first element.
        /// - Returns: The result of the closure, or `nil` if the list is empty.
        /// - Complexity: O(1)
        @inlinable
        public func first<R>(_ body: (borrowing Element) -> R) -> R? {
            guard _storage.header.count > 0 else { return nil }
            let headIndex = _storage.header.head
            return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                body(unsafe nodes[headIndex].element)
            }
        }

        /// Peeks at the last element without removing it.
        ///
        /// Uses a closure to support `~Copyable` elements via borrowing.
        ///
        /// - Parameter body: A closure that receives a borrowed reference to the last element.
        /// - Returns: The result of the closure, or `nil` if the list is empty.
        /// - Complexity: O(1)
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

extension List.Linked {
    /// Returns the first element, or `nil` if empty.
    ///
    /// This is a convenience property for `Copyable` elements. For `~Copyable`
    /// elements, use ``peekFirst(_:)`` with a closure.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var first: Element? {
        guard _storage.header.count > 0 else { return nil }
        let headIndex = _storage.header.head
        return unsafe _storage.withUnsafeMutablePointerToElements { nodes in
            unsafe nodes[headIndex].element
        }
    }

    /// Returns the last element, or `nil` if empty.
    ///
    /// This is a convenience property for `Copyable` elements. For `~Copyable`
    /// elements, use ``peekLast(_:)`` with a closure.
    ///
    /// - Complexity: O(1)
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

extension List.Linked where Element: ~Copyable {
    /// Calls the given closure for each element, front to back.
    ///
    /// - Parameter body: A closure that receives each element.
    /// - Complexity: O(n) where n is the number of elements.
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
    @inlinable
    public var reversed: Reversed {
        precondition(N >= 2, "reversed requires N >= 2 (doubly-linked)")
        return Reversed(_storage: _storage)
    }
}

extension List.Linked where Element: ~Copyable {
    /// A reversed view of the linked list for back-to-front iteration.
    ///
    /// Access via the ``List/Linked/reversed`` property.
    public struct Reversed {
        @usableFromInline
        let _storage: Storage

        @usableFromInline
        init(_storage: Storage) {
            self._storage = _storage
        }

        /// Calls the given closure for each element, back to front.
        ///
        /// - Parameter body: A closure that receives each element.
        /// - Complexity: O(n) where n is the number of elements.
        @inlinable
        public func forEach(_ body: (borrowing Element) -> Void) {
            var index = _storage.header.tail
            _ = unsafe _storage.withUnsafeMutablePointerToElements { nodes in
                while index >= 0 {
                    body(unsafe nodes[index].element)
                    index = unsafe nodes[index].links[1]  // prev link
                }
            }
        }
    }
}

// MARK: - Sequence (Copyable elements only)

extension List.Linked: Sequence where Element: Copyable {
    /// An iterator over the elements of a linked list.
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

extension List.Linked: Equatable where Element: Equatable {
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

extension List.Linked: Hashable where Element: Hashable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_storage.header.count)
        forEach { hasher.combine($0) }
    }
}

// MARK: - Sendable

extension List.Linked: @unchecked Sendable where Element: Sendable {}
extension List.Linked.Bounded: @unchecked Sendable where Element: Sendable {}
