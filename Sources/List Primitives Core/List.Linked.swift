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
        package struct Header {
            /// Index of first element (-1 if empty).
            @usableFromInline package var head: Int
            /// Index of last element (-1 if empty).
            @usableFromInline package var tail: Int
            /// Index of first free slot (-1 if none).
            @usableFromInline package var freeHead: Int
            /// Number of active elements.
            @usableFromInline package var count: Int
            /// Total node capacity.
            @usableFromInline package var capacity: Int

            @usableFromInline
            package init() {
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
        package struct Node: ~Copyable {
            /// The element stored in this node.
            @usableFromInline package var element: Element
            /// Links to other nodes. Index 0 is next, index 1 is prev (if N >= 2).
            @usableFromInline package var links: InlineArray<N, Int>

            @usableFromInline
            package init(element: consuming Element, links: InlineArray<N, Int>) {
                self.element = element
                self.links = links
            }

            /// The next node index (-1 for none/tail).
            @usableFromInline
            package var nextIndex: Int {
                get { links[0] }
                set { links[0] = newValue }
            }

            /// The previous node index (-1 for none/head). Only valid when N >= 2.
            @usableFromInline
            package var prevIndex: Int {
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
        package final class Storage: ManagedBuffer<Header, Node> {

            @usableFromInline
            package static func create() -> Storage {
                let storage = Storage.create(minimumCapacity: 0) { _ in Header() }
                return unsafe unsafeDowncast(storage, to: Storage.self)
            }

            @usableFromInline
            package static func create(minimumCapacity: Int) -> Storage {
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
            package var _nodesPointer: UnsafeMutablePointer<Node> {
                unsafe withUnsafeMutablePointerToElements { unsafe $0 }
            }

            /// Initializes a node at the given index.
            @usableFromInline
            package func _initializeNode(at index: Int, element: consuming Element, links: InlineArray<N, Int>) {
                let ptr = unsafe withUnsafeMutablePointerToElements { unsafe $0 + index }
                unsafe ptr.initialize(to: Node(element: element, links: links))
            }

            /// Deinitializes the node at the given index.
            @usableFromInline
            package func _deinitializeNode(at index: Int) {
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
            package func _loadFreeNext(at index: Int) -> Int {
                unsafe withUnsafeMutablePointerToElements { ptr in
                    unsafe UnsafeRawPointer(ptr.advanced(by: index)).load(as: Int.self)
                }
            }

            /// Stores the free-list next index into a freed slot.
            ///
            /// - Precondition: The slot at `index` must be deinitialized/free.
            @usableFromInline
            package func _storeFreeNext(at index: Int, next: Int) {
                unsafe withUnsafeMutablePointerToElements { ptr in
                    unsafe UnsafeMutableRawPointer(ptr.advanced(by: index)).storeBytes(of: next, as: Int.self)
                }
            }

            /// Moves all elements to new storage, linearizing the list.
            ///
            /// After this call, `self` is in an empty state (header reset) so that
            /// `deinit` won't double-destroy the moved elements.
            @usableFromInline
            package func _moveAllElements(to newStorage: Storage) {
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
        package var _buffer: Buffer<Element>.Linked<N>

        // Tag enums for Property.View.Read accessors [PATTERN-022]
        public enum Peek {}
        public enum Reversed {}

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
            package var _buffer: Buffer<Element>.Linked<N>

            // Tag enums for Property.View.Read accessors [PATTERN-022]
            public enum Peek {}
            public enum Reversed {}

            /// The maximum number of elements the list can hold.
            public let capacity: Int

            /// Creates a list with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of elements. Must be non-negative.
            /// - Throws: ``Bounded/Error/invalidCapacity`` if capacity is negative.
            @inlinable
            public init(capacity: Int) throws(__ListLinkedBoundedError) {
                guard capacity > 0 else {
                    throw .invalidCapacity
                }
                self._buffer = try! .create(capacity: capacity)
                self.capacity = capacity
            }
        }

        // Note: Inline and Small variants require Copyable elements due to InlineArray
        // limitations. They are declared in an extension below.

        // MARK: - Init

        /// Creates an empty linked list.
        ///
        /// Allocates an initial pool with capacity 4.
        @inlinable
        public init() {
            precondition(N >= 1 && N <= 2, "Linked<N> requires N in 1...2")
            self._buffer = try! .create(capacity: 4)
        }

        /// Creates a list with reserved capacity.
        ///
        /// Pre-allocates storage for the specified number of elements.
        ///
        /// - Parameter capacity: Number of elements to reserve space for. Must be positive.
        /// - Throws: ``Linked/Error/invalidCapacity`` if capacity is not positive.
        @inlinable
        public init(reservingCapacity capacity: Int) throws(List<Element>.Linked<N>.Error) {
            precondition(N >= 1 && N <= 2, "Linked<N> requires N in 1...2")
            guard capacity > 0 else {
                throw .invalidCapacity
            }
            self._buffer = try! .create(capacity: capacity)
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
        package var _elements: InlineArray<capacity, Element?>

        /// Storage for links. Each slot stores [next, prev?] indices.
        @usableFromInline
        package var _links: InlineArray<capacity, InlineArray<N, Int>>

        /// Index of first element (-1 if empty).
        @usableFromInline
        package var _head: Int

        /// Index of last element (-1 if empty).
        @usableFromInline
        package var _tail: Int

        /// Index of first free slot (-1 if none).
        @usableFromInline
        package var _freeHead: Int

        /// Current element count.
        @usableFromInline
        package var _count: Int

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
        package var _inlineElements: InlineArray<inlineCapacity, Element?>

        /// Storage for inline links.
        @usableFromInline
        package var _inlineLinks: InlineArray<inlineCapacity, InlineArray<N, Int>>

        /// Index of first element (-1 if empty).
        @usableFromInline
        package var _head: Int

        /// Index of last element (-1 if empty).
        @usableFromInline
        package var _tail: Int

        /// Index of first free slot (-1 if none, only for inline mode).
        @usableFromInline
        package var _freeHead: Int

        /// Current element count.
        @usableFromInline
        package var _count: Int

        /// Heap storage when spilled. Nil when using inline storage.
        @usableFromInline
        package var _heap: Storage?

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

// MARK: - Sendable

extension List.Linked: @unchecked Sendable where Element: Sendable {}
extension List.Linked.Bounded: @unchecked Sendable where Element: Sendable {}
extension List.Linked.Inline: @unchecked Sendable where Element: Sendable {}
extension List.Linked.Small: @unchecked Sendable where Element: Sendable {}
