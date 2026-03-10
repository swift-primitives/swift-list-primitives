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
public import Buffer_Linked_Inline_Primitives

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
            public let capacity: Index_Primitives.Index<Element>.Count

            /// Creates a list with the specified capacity.
            ///
            /// - Parameter capacity: Maximum number of elements. Must be non-negative.
            /// - Throws: ``Bounded/Error/invalidCapacity`` if capacity is negative.
            @inlinable
            public init(capacity: Index_Primitives.Index<Element>.Count) throws(__ListLinkedBoundedError) {
                guard capacity > .zero else {
                    throw .invalidCapacity
                }
                self._buffer = try! .create(capacity: capacity.retag())
                self.capacity = capacity
            }
        }

        // MARK: - Inline (Fixed-Capacity, Stack-Allocated)

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
        /// ## ~Copyable Support
        ///
        /// Unlike previous versions, Inline now supports `~Copyable` elements
        /// via `Buffer.Linked.Inline` (which uses `Storage<Node>.Inline` with `@_rawLayout`).
        ///
        /// ## Non-Copyable Container
        ///
        /// `Inline` is unconditionally `~Copyable` (move-only) because it contains
        /// `Storage.Inline` which uses `@_rawLayout`.
        public struct Inline<let capacity: Int>: ~Copyable {
            @usableFromInline
            package var _buffer: Buffer<Element>.Linked<N>.Inline<capacity>

            // WORKAROUND: Forces compiler to execute deinit body.
            // TRACKING: swiftlang/swift #86652 variant (nested ~Copyable deinit chain)
            // WHEN TO REMOVE: When the compiler correctly destroys ~Copyable structs
            //      with cross-package value-generic stored properties.
            private var _deinitWorkaround: AnyObject? = nil

            // Tag enums for Property.View.Read accessors [PATTERN-022]
            public enum Peek {}
            public enum Reversed {}

            @inlinable
            package init(_buffer: consuming Buffer<Element>.Linked<N>.Inline<capacity>) {
                self._buffer = _buffer
            }

            deinit {
                // WORKAROUND: Manually clean up elements via the mutating path.
                // TRACKING: swiftlang/swift #86652 variant
                unsafe withUnsafePointer(to: _buffer) { ptr in
                    unsafe UnsafeMutablePointer(mutating: ptr).pointee.removeAll()
                }
            }
        }

        // MARK: - Small (Inline + Heap Spill)

        /// A linked list with small-buffer optimization (SmallVec pattern).
        ///
        /// `Linked.Small` stores up to `inlineCapacity` elements in inline storage,
        /// then automatically spills to heap storage when that capacity is exceeded.
        ///
        /// ## Example
        ///
        /// ```swift
        /// var list = List<Int>.Linked<2>.Small<4>()
        /// list.prepend(1)  // Inline
        /// list.prepend(2)  // Inline
        /// list.prepend(3)  // Inline
        /// list.prepend(4)  // Inline
        /// list.prepend(5)  // Spills to heap
        /// ```
        ///
        /// ## ~Copyable Support
        ///
        /// Supports `~Copyable` elements via `Buffer.Linked.Small`.
        ///
        /// ## Non-Copyable Container
        ///
        /// `Small` is unconditionally `~Copyable` because it contains inline storage.
        @safe
        public struct Small<let inlineCapacity: Int>: ~Copyable {
            @usableFromInline
            package var _buffer: Buffer<Element>.Linked<N>.Small<inlineCapacity>

            // WORKAROUND: Forces compiler to execute deinit body.
            // TRACKING: swiftlang/swift #86652 variant (nested ~Copyable deinit chain)
            // WHEN TO REMOVE: When the compiler correctly destroys ~Copyable structs
            //      with cross-package value-generic stored properties.
            private var _deinitWorkaround: AnyObject? = nil

            @inlinable
            package init(_buffer: consuming Buffer<Element>.Linked<N>.Small<inlineCapacity>) {
                self._buffer = _buffer
            }

            deinit {
                // WORKAROUND: Manually clean up elements via the mutating path.
                // TRACKING: swiftlang/swift #86652 variant
                unsafe withUnsafePointer(to: _buffer) { ptr in
                    unsafe UnsafeMutablePointer(mutating: ptr).pointee.removeAll()
                }
            }

            /// Whether the list is currently using heap storage.
            @inlinable
            public var isSpilled: Bool { _buffer.isSpilled }
        }

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

// Note: List.Linked.Inline and List.Linked.Small are UNCONDITIONALLY ~Copyable
// because they contain Storage.Inline (which uses @_rawLayout).

// MARK: - Sendable

extension List.Linked: @unchecked Sendable where Element: Sendable {}
extension List.Linked.Bounded: @unchecked Sendable where Element: Sendable {}
extension List.Linked.Inline: @unchecked Sendable where Element: Sendable {}
extension List.Linked.Small: @unchecked Sendable where Element: Sendable {}
