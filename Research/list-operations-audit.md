# List Operations Audit

<!--
---
version: 1.0.0
last_updated: 2026-02-16
status: RECOMMENDATION
tier: 1
---
-->

## Context

Proactive audit of swift-list-primitives to inventory all public operations and compare against canonical Linked List ADT operations.

**Trigger**: [RES-012] Discovery -- proactive operations audit across 13 data structure packages.

**Scope**: Package-specific (swift-list-primitives).

## Question

Does swift-list-primitives provide the canonical operations expected of the Linked List ADT? Which operations are present, which are missing, and which missing operations are intentionally absent at the primitives layer?

## Canonical Operations (ADT Reference)

| Operation | Expected Complexity | Description |
|-----------|-------------------|-------------|
| push_front(x) | O(1) | Add to front |
| pop_front() | O(1) | Remove from front |
| push_back(x) | O(1) with tail pointer | Add to back |
| pop_back() | O(1) doubly-linked, O(n) singly | Remove from back |
| insert_after(node, x) | O(1) | Insert after given node |
| delete(node) | O(1) | Remove given node |
| splice/concat | O(1) | Join two lists |
| iterate | O(n) | Visit all elements |
| find(x) | O(n) | Linear search |
| access(i) | O(n) | Indexed access |
| size/count | O(1) or O(n) | Element count |
| isEmpty | O(1) | Empty check |

## Architecture Overview

`List.Linked<N>` is parameterized by link count:
- `N=1`: Singly-linked (forward link only). Tail pointer maintained for O(1) append.
- `N=2`: Doubly-linked (forward + backward links). O(1) at both ends.

Arena-based storage: all nodes are stored contiguously in a `Buffer.Linked<N>` arena. Nodes reference each other by index, not pointer. This improves cache locality versus traditional heap-allocated nodes.

Four variants exist:
- `List.Linked<N>` -- dynamic, growable, CoW (Copyable elements)
- `List.Linked<N>.Bounded` -- fixed-capacity, throws on overflow
- `List.Linked<N>.Inline<capacity>` -- zero-allocation inline storage, compile-time capacity
- `List.Linked<N>.Small<inlineCapacity>` -- inline storage with automatic heap spill

---

## Current Operations Inventory

### Variant: List.Linked (Dynamic)

**Source files**:
- `/Users/coen/Developer/swift-primitives/swift-list-primitives/Sources/List Primitives Core/List.Linked.swift` (struct, init, variants)
- `/Users/coen/Developer/swift-primitives/swift-list-primitives/Sources/List Linked Primitives/List.Linked ~Copyable.swift` (~Copyable operations)
- `/Users/coen/Developer/swift-primitives/swift-list-primitives/Sources/List Linked Primitives/List.Linked Copyable.swift` (Copyable overloads, Sequence, Equatable, Hashable)

#### Construction

| Method | Signature | Constraint | Source |
|--------|-----------|------------|--------|
| `init()` | `public init()` | `Element: ~Copyable` | `List.Linked.swift:205` |
| `init(reservingCapacity:)` | `public init(reservingCapacity capacity: Int) throws(Error)` | `Element: ~Copyable` | `List.Linked.swift:217` |

#### Properties

| Property | Signature | Complexity | Constraint | Source |
|----------|-----------|------------|------------|--------|
| `count` | `public var count: Index<Element>.Count` | O(1) | `Element: ~Copyable` | `~Copyable.swift:20` |
| `isEmpty` | `public var isEmpty: Bool` | O(1) | `Element: ~Copyable` | `~Copyable.swift:24` |
| `capacity` | `public var capacity: Index<Element>.Count` | O(1) | `Element: ~Copyable` | `~Copyable.swift:28` |
| `first` | `public var first: Element?` | O(1) | `Element: Copyable` | `Copyable.swift:69` |
| `last` | `public var last: Element?` | O(1) | `Element: Copyable` | `Copyable.swift:80` |

#### Mutation

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| push_front | `prepend(_:)` | `public mutating func prepend(_ element: consuming Element)` | O(1) amortized | `Element: ~Copyable` | `~Copyable.swift:61` |
| push_front | `prepend(_:)` | `public mutating func prepend(_ element: Element)` | O(1) amortized | `Element: Copyable` (CoW) | `Copyable.swift:22` |
| push_back | `append(_:)` | `public mutating func append(_ element: consuming Element)` | O(1) amortized | `Element: ~Copyable` | `~Copyable.swift:71` |
| push_back | `append(_:)` | `public mutating func append(_ element: Element)` | O(1) amortized | `Element: Copyable` (CoW) | `Copyable.swift:31` |
| pop_front | `popFirst()` | `public mutating func popFirst() -> Element?` | O(1) | `Element: ~Copyable` | `~Copyable.swift:82` |
| pop_front | `popFirst()` | `public mutating func popFirst() -> Element?` | O(1) | `Element: Copyable` (CoW) | `Copyable.swift:38` |
| pop_back | `popLast()` | `public mutating func popLast() -> Element?` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `~Copyable.swift:92` |
| pop_back | `popLast()` | `public mutating func popLast() -> Element?` | O(1) N>=2, O(n) N==1 | `Element: Copyable` (CoW) | `Copyable.swift:45` |
| pop_front (throwing) | `removeFirst()` | `public mutating func removeFirst() throws(Error) -> Element` | O(1) | `Element: ~Copyable` | `~Copyable.swift:102` |
| pop_back (throwing) | `removeLast()` | `public mutating func removeLast() throws(Error) -> Element` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `~Copyable.swift:115` |
| -- | `clear(keepingCapacity:)` | `public mutating func clear(keepingCapacity: Bool = true)` | O(n) | `Element: ~Copyable` | `~Copyable.swift:128` |
| -- | `clear(keepingCapacity:)` | `public mutating func clear(keepingCapacity: Bool = true)` | O(n) | `Element: Copyable` (CoW) | `Copyable.swift:51` |
| -- | `reserve(_:)` | `public mutating func reserve(_ minimumCapacity: Int)` | amortized | `Element: ~Copyable` | `~Copyable.swift:47` |

#### Observation (Peek)

| Method | Signature | Complexity | Constraint | Source |
|--------|-----------|------------|------------|--------|
| `peek.first(_:)` | `public func first<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Element: ~Copyable` | `~Copyable.swift:176` |
| `peek.last(_:)` | `public func last<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Element: ~Copyable` | `~Copyable.swift:190` |

Access via `Property<Peek, Self>.View.Read.Typed<Element>.Valued<N>` -- reached through `list.peek.first { ... }`.

#### Traversal

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| iterate | `forEach(_:)` | `public func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Element: ~Copyable` | `~Copyable.swift:205` |
| iterate (reversed) | `reversed.forEach(_:)` | `public func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Element: ~Copyable`, N>=2 | `~Copyable.swift:244` |

Access via `Property<Reversed, Self>.View.Read.Typed<Element>.Valued<N>` -- reached through `list.reversed.forEach { ... }`.

#### Protocol Conformances

| Protocol | Constraint | Source |
|----------|------------|--------|
| `Copyable where Element: Copyable` | Conditional | `List.Linked.swift:230` |
| `@unchecked Sendable where Element: Sendable` | Conditional | `List.Linked.swift:240` |
| `Swift.Sequence where Element: Copyable` | Conditional | `Copyable.swift:87` |
| `Equatable where Element: Equatable` | Conditional | `Copyable.swift:112` |
| `Hashable where Element: Hashable` | Conditional | `Copyable.swift:121` |

#### Iterator

| Type | Signature | Source |
|------|-----------|--------|
| `List.Linked.Iterator` | `public struct Iterator: Sequence.Iterator.Protocol, IteratorProtocol` | `Copyable.swift:89` |
| `next()` | `public mutating func next() -> Element?` | `Copyable.swift:99` |
| `makeIterator()` | `public func makeIterator() -> Iterator` | `Copyable.swift:105` |

#### Tag Enums

| Type | Purpose | Source |
|------|---------|--------|
| `Peek` | Tag for Property.View peek accessor | `List.Linked.swift:75` |
| `Reversed` | Tag for Property.View reversed accessor | `List.Linked.swift:76` |

#### Error Types

| Type | Cases | Source |
|------|-------|--------|
| `List.Linked.Error` (alias `__ListLinkedError`) | `.empty`, `.invalidCapacity` | `List.Linked.Error.swift:30-36` |

---

### Variant: List.Linked.Bounded

**Source file**: `/Users/coen/Developer/swift-primitives/swift-list-primitives/Sources/List Linked Primitives/List.Linked.Bounded.swift`

#### Construction

| Method | Signature | Source |
|--------|-----------|--------|
| `init(capacity:)` | `public init(capacity: Index<Element>.Count) throws(__ListLinkedBoundedError)` | `List.Linked.swift:111` |

#### Properties

| Property | Signature | Complexity | Constraint | Source |
|----------|-----------|------------|------------|--------|
| `count` | `public var count: Index<Element>.Count` | O(1) | `Element: ~Copyable` | `Bounded.swift:20` |
| `isEmpty` | `public var isEmpty: Bool` | O(1) | `Element: ~Copyable` | `Bounded.swift:24` |
| `isFull` | `public var isFull: Bool` | O(1) | `Element: ~Copyable` | `Bounded.swift:28` |
| `capacity` | `public let capacity: Index<Element>.Count` | O(1) | `Element: ~Copyable` | `List.Linked.swift:104` |
| `first` | `public var first: Element?` | O(1) | `Element: Copyable` | `Bounded.swift:205` |
| `last` | `public var last: Element?` | O(1) | `Element: Copyable` | `Bounded.swift:211` |

#### Mutation

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| push_front | `prepend(_:)` | `public mutating func prepend(_ element: consuming Element) throws(__ListLinkedBoundedError)` | O(1) | `Element: ~Copyable` | `Bounded.swift:41` |
| push_front | `prepend(_:)` | `public mutating func prepend(_ element: Element) throws(__ListLinkedBoundedError)` | O(1) | `Element: Copyable` (CoW) | `Bounded.swift:123` |
| push_back | `append(_:)` | `public mutating func append(_ element: consuming Element) throws(__ListLinkedBoundedError)` | O(1) | `Element: ~Copyable` | `Bounded.swift:52` |
| push_back | `append(_:)` | `public mutating func append(_ element: Element) throws(__ListLinkedBoundedError)` | O(1) | `Element: Copyable` (CoW) | `Bounded.swift:131` |
| pop_front | `popFirst()` | `public mutating func popFirst() -> Element?` | O(1) | `Element: ~Copyable` | `Bounded.swift:63` |
| pop_front | `popFirst()` | `public mutating func popFirst() -> Element?` | O(1) | `Element: Copyable` (CoW) | `Bounded.swift:140` |
| pop_back | `popLast()` | `public mutating func popLast() -> Element?` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `Bounded.swift:72` |
| pop_back | `popLast()` | `public mutating func popLast() -> Element?` | O(1) N>=2, O(n) N==1 | `Element: Copyable` (CoW) | `Bounded.swift:148` |
| pop_front (throwing) | `removeFirst()` | `public mutating func removeFirst() throws(__ListLinkedBoundedError) -> Element` | O(1) | `Element: ~Copyable` | `Bounded.swift:83` |
| pop_back (throwing) | `removeLast()` | `public mutating func removeLast() throws(__ListLinkedBoundedError) -> Element` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `Bounded.swift:96` |
| -- | `clear()` | `public mutating func clear()` | O(n) | `Element: ~Copyable` | `Bounded.swift:107` |
| -- | `clear()` | `public mutating func clear()` | O(n) | `Element: Copyable` (CoW) | `Bounded.swift:155` |

#### Observation (Peek)

| Method | Signature | Complexity | Constraint | Source |
|--------|-----------|------------|------------|--------|
| `peek.first(_:)` | `public func first<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Element: ~Copyable` | `Bounded.swift:187` |
| `peek.last(_:)` | `public func last<R>(_ body: (borrowing Element) -> R) -> R?` | O(1) | `Element: ~Copyable` | `Bounded.swift:195` |

#### Traversal

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| iterate | `forEach(_:)` | `public func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Element: ~Copyable` | `Bounded.swift:221` |
| iterate (reversed) | `reversed.forEach(_:)` | `public func forEach(_ body: (borrowing Element) -> Void)` | O(n) | `Element: ~Copyable`, N>=2 | `Bounded.swift:247` |

#### Protocol Conformances

| Protocol | Constraint | Source |
|----------|------------|--------|
| `Copyable where Element: Copyable` | Conditional | `List.Linked.swift:233` |
| `@unchecked Sendable where Element: Sendable` | Conditional | `List.Linked.swift:241` |
| `Swift.Sequence where Element: Copyable` | Conditional | `Bounded.swift:256` |
| `Equatable where Element: Equatable` | Conditional | `Bounded.swift:281` |
| `Hashable where Element: Hashable` | Conditional | `Bounded.swift:290` |

#### Error Types

| Type | Cases | Source |
|------|-------|--------|
| `List.Linked.Bounded.Error` (alias `__ListLinkedBoundedError`) | `.empty`, `.invalidCapacity`, `.overflow` | `List.Linked.Error.swift:41-50` |

---

### Variant: List.Linked.Inline

**Source file**: `/Users/coen/Developer/swift-primitives/swift-list-primitives/Sources/List Linked Primitives/List.Linked.Inline.swift`

Unconditionally `~Copyable` (uses `@_rawLayout` via `Storage.Inline`). Cannot conform to `Sequence`, `Equatable`, or `Hashable`.

#### Construction

| Method | Signature | Source |
|--------|-----------|--------|
| `init()` | `public init()` | `Inline.swift:19` |

#### Properties

| Property | Signature | Complexity | Constraint | Source |
|----------|-----------|------------|------------|--------|
| `count` | `public var count: Index<Element>.Count` | O(1) | `Element: ~Copyable` | `Inline.swift:29` |
| `isEmpty` | `public var isEmpty: Bool` | O(1) | `Element: ~Copyable` | `Inline.swift:33` |
| `isFull` | `public var isFull: Bool` | O(1) | `Element: ~Copyable` | `Inline.swift:37` |
| `first` | `public var first: Element?` | O(1) | `Element: Copyable` | `Inline.swift:179` |
| `last` | `public var last: Element?` | O(1) | `Element: Copyable` | `Inline.swift:186` |

#### Mutation

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| push_front | `prepend(_:)` | `public mutating func prepend(_ element: consuming Element) throws(__ListLinkedInlineError)` | O(1) | `Element: ~Copyable` | `Inline.swift:50` |
| push_back | `append(_:)` | `public mutating func append(_ element: consuming Element) throws(__ListLinkedInlineError)` | O(1) | `Element: ~Copyable` | `Inline.swift:64` |
| pop_front | `popFirst()` | `public mutating func popFirst() -> Element?` | O(1) | `Element: ~Copyable` | `Inline.swift:78` |
| pop_back | `popLast()` | `public mutating func popLast() -> Element?` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `Inline.swift:87` |
| pop_front (throwing) | `removeFirst()` | `public mutating func removeFirst() throws(__ListLinkedInlineError) -> Element` | O(1) | `Element: ~Copyable` | `Inline.swift:98` |
| pop_back (throwing) | `removeLast()` | `public mutating func removeLast() throws(__ListLinkedInlineError) -> Element` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `Inline.swift:111` |
| -- | `clear()` | `public mutating func clear()` | O(n) | `Element: ~Copyable` | `Inline.swift:122` |

#### Observation (Peek)

| Method | Signature | Complexity | Constraint | Source |
|--------|-----------|------------|------------|--------|
| `peekFirst(_:)` | `public func peekFirst<R, E: Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R?` | O(1) | `Element: ~Copyable` | `Inline.swift:157` |
| `peekLast(_:)` | `public func peekLast<R, E: Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R?` | O(1) | `Element: ~Copyable` | `Inline.swift:167` |

Note: Inline uses direct `peekFirst`/`peekLast` methods rather than the `peek.first`/`peek.last` Property.View pattern used by Linked and Bounded.

#### Traversal

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| iterate | `forEach(_:)` | `public func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` | O(n) | `Element: ~Copyable` | `Inline.swift:134` |
| iterate | `forEach(_:)` | `public func forEach(_ body: (Element) -> Void)` | O(n) | `Element: Copyable` | `Inline.swift:201` |
| iterate (reversed) | `forEachReversed(_:)` | `public func forEachReversed<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` | O(n) | `Element: ~Copyable`, N>=2 | `Inline.swift:143` |

Note: Inline uses direct `forEachReversed(_:)` method rather than `reversed.forEach` Property.View pattern.

#### Protocol Conformances

| Protocol | Constraint | Source |
|----------|------------|--------|
| `@unchecked Sendable where Element: Sendable` | Conditional | `List.Linked.swift:242` |

Cannot conform to `Sequence`, `Equatable`, or `Hashable` (unconditionally `~Copyable`).

#### Error Types

| Type | Cases | Source |
|------|-------|--------|
| `List.Linked.Inline.Error` (alias `__ListLinkedInlineError`) | `.empty`, `.overflow` | `List.Linked.Error.swift:55-61` |

---

### Variant: List.Linked.Small

**Source file**: `/Users/coen/Developer/swift-primitives/swift-list-primitives/Sources/List Linked Primitives/List.Linked.Small.swift`

Unconditionally `~Copyable` (contains inline storage). Cannot conform to `Sequence`, `Equatable`, or `Hashable`.

#### Construction

| Method | Signature | Source |
|--------|-----------|--------|
| `init()` | `public init()` | `Small.swift:19` |

#### Properties

| Property | Signature | Complexity | Constraint | Source |
|----------|-----------|------------|------------|--------|
| `count` | `public var count: Index<Element>.Count` | O(1) | `Element: ~Copyable` | `Small.swift:29` |
| `isEmpty` | `public var isEmpty: Bool` | O(1) | `Element: ~Copyable` | `Small.swift:33` |
| `capacity` | `public var capacity: Index<Element>.Count` | O(1) | `Element: ~Copyable` | `Small.swift:37` |
| `isSpilled` | `public var isSpilled: Bool` | O(1) | `Element: ~Copyable` | `List.Linked.swift:196` |
| `first` | `public var first: Element?` | O(1) | `Element: Copyable` | `Small.swift:173` |
| `last` | `public var last: Element?` | O(1) | `Element: Copyable` | `Small.swift:181` |

#### Mutation

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| push_front | `prepend(_:)` | `public mutating func prepend(_ element: consuming Element)` | O(1) amortized | `Element: ~Copyable` | `Small.swift:51` |
| push_back | `append(_:)` | `public mutating func append(_ element: consuming Element)` | O(1) amortized | `Element: ~Copyable` | `Small.swift:62` |
| pop_front | `popFirst()` | `public mutating func popFirst() -> Element?` | O(1) | `Element: ~Copyable` | `Small.swift:72` |
| pop_back | `popLast()` | `public mutating func popLast() -> Element?` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `Small.swift:82` |
| pop_front (throwing) | `removeFirst()` | `public mutating func removeFirst() throws(__ListLinkedSmallError) -> Element` | O(1) | `Element: ~Copyable` | `Small.swift:92` |
| pop_back (throwing) | `removeLast()` | `public mutating func removeLast() throws(__ListLinkedSmallError) -> Element` | O(1) N>=2, O(n) N==1 | `Element: ~Copyable` | `Small.swift:105` |
| -- | `clear()` | `public mutating func clear()` | O(n) | `Element: ~Copyable` | `Small.swift:116` |

#### Observation (Peek)

| Method | Signature | Complexity | Constraint | Source |
|--------|-----------|------------|------------|--------|
| `peekFirst(_:)` | `public func peekFirst<R, E: Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R?` | O(1) | `Element: ~Copyable` | `Small.swift:151` |
| `peekLast(_:)` | `public func peekLast<R, E: Error>(_ body: (borrowing Element) throws(E) -> R) throws(E) -> R?` | O(1) | `Element: ~Copyable` | `Small.swift:161` |

Note: Same pattern as Inline -- direct methods, not Property.View.

#### Traversal

| Canonical Op | Method | Signature | Complexity | Constraint | Source |
|-------------|--------|-----------|------------|------------|--------|
| iterate | `forEach(_:)` | `public func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` | O(n) | `Element: ~Copyable` | `Small.swift:128` |
| iterate | `forEach(_:)` | `public func forEach(_ body: (Element) -> Void)` | O(n) | `Element: Copyable` | `Small.swift:195` |
| iterate (reversed) | `forEachReversed(_:)` | `public func forEachReversed<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)` | O(n) | `Element: ~Copyable`, N>=2 | `Small.swift:137` |

#### Protocol Conformances

| Protocol | Constraint | Source |
|----------|------------|--------|
| `@unchecked Sendable where Element: Sendable` | Conditional | `List.Linked.swift:243` |

Cannot conform to `Sequence`, `Equatable`, or `Hashable` (unconditionally `~Copyable`).

#### Error Types

| Type | Cases | Source |
|------|-------|--------|
| `List.Linked.Small.Error` (alias `__ListLinkedSmallError`) | `.empty` | `List.Linked.Error.swift:66-69` |

---

### Additional Operations (Beyond Canonical ADT)

These operations are present in swift-list-primitives but not in the canonical linked list ADT reference:

| Operation | Variant(s) | Description |
|-----------|-----------|-------------|
| `removeFirst() throws` | All | Throwing variant of `popFirst()` -- typed throws on empty |
| `removeLast() throws` | All | Throwing variant of `popLast()` -- typed throws on empty |
| `clear(keepingCapacity:)` | Linked | Bulk removal with capacity retention option |
| `clear()` | Bounded, Inline, Small | Bulk removal |
| `reserve(_:)` | Linked | Capacity pre-allocation |
| `peek.first(_:)` / `peekFirst(_:)` | All | Non-destructive observation of head via borrowing closure |
| `peek.last(_:)` / `peekLast(_:)` | All | Non-destructive observation of tail via borrowing closure |
| `reversed.forEach(_:)` / `forEachReversed(_:)` | All (N>=2) | Reverse-order traversal |
| `isFull` | Bounded, Inline | Capacity saturation check |
| `isSpilled` | Small | Inline-to-heap spill detection |
| `capacity` | Linked, Bounded, Small | Current or maximum capacity |
| `first` / `last` (Copyable) | All | Non-destructive head/tail observation (Copyable shorthand) |
| `Sequence` conformance | Linked, Bounded | `for-in` iteration and stdlib interop |
| `Equatable` conformance | Linked, Bounded | Element-wise structural equality |
| `Hashable` conformance | Linked, Bounded | Consistent hashing |
| CoW-safe overloads | Linked, Bounded | Copy-on-write aware mutation for Copyable elements |

---

## Gap Analysis

### Present and Correctly Mapped

| Canonical Operation | Implementation | Complexity | Notes |
|--------------------|---------------|------------|-------|
| push_front(x) | `prepend(_:)` | O(1) amortized | All 4 variants. ~Copyable + Copyable overloads on Linked/Bounded. |
| pop_front() | `popFirst()` | O(1) | All 4 variants. Returns `Optional`. |
| push_back(x) | `append(_:)` | O(1) amortized | All 4 variants. Tail pointer maintained even for N==1. |
| pop_back() | `popLast()` | O(1) N>=2, O(n) N==1 | All 4 variants. Correctly documents O(n) for singly-linked. |
| iterate | `forEach(_:)` | O(n) | All 4 variants. Borrowing closure for ~Copyable support. |
| iterate (reverse) | `reversed.forEach`/`forEachReversed` | O(n) | All 4 variants (N>=2 precondition). |
| size/count | `count` | O(1) | All 4 variants. Maintained as stored header field. |
| isEmpty | `isEmpty` | O(1) | All 4 variants. |

### Missing -- Should Add (Primitives Layer)

| Canonical Operation | Priority | Rationale |
|--------------------|----------|-----------|
| insert_after(node, x) | **High** | O(1) positional insertion is the defining advantage of linked lists over arrays. Without it, the list is functionally a double-ended queue. Requires a cursor or node-handle API. The `list-discipline-boundary-analysis.md` research also identifies this as the highest-priority gap. |
| delete(node) | **High** | O(1) positional deletion at a known cursor/node position. Same rationale as insert_after -- without positional deletion, users must pop from ends only. |
| splice/concat | **High** | O(1) transfer of all nodes from one list to another. This is the signature operation that only linked lists can perform in constant time. Per STL and Rust, this is a core member function. Requires shared arena or arena-transfer semantics. |

These three operations together form the **cursor/splice interface** that distinguishes a linked list from a deque. Without them, the data structure provides deque semantics (push/pop at both ends) but not true linked list semantics (positional mutation at known nodes).

### Missing -- Intentionally Absent (Higher Layer)

| Canonical Operation | Layer | Rationale |
|--------------------|-------|-----------|
| find(x) | Foundations (Layer 3) or consumer code | Requires `Equatable` constraint. Primitives layer avoids protocol constraints beyond `~Copyable`/`Copyable`/`Sendable`. Consumers with `Copyable` elements can use `Sequence`-based methods (`.first(where:)`, `.contains(where:)`). |
| access(i) | **Intentionally refused** | Linked lists do not support O(1) indexed access. Providing `subscript(Index)` would be misleading. The `List.Index.swift` file explicitly documents: "Linked lists do not support O(1) indexed access." This is a correct semantic refusal, not a missing feature. |

---

## Summary: Operation Coverage by Variant

| Canonical Op | Linked | Bounded | Inline | Small |
|-------------|:------:|:-------:|:------:|:-----:|
| push_front | Y | Y | Y | Y |
| pop_front | Y | Y | Y | Y |
| push_back | Y | Y | Y | Y |
| pop_back | Y | Y | Y | Y |
| insert_after | -- | -- | -- | -- |
| delete(node) | -- | -- | -- | -- |
| splice/concat | -- | -- | -- | -- |
| iterate | Y | Y | Y | Y |
| find(x) | (Sequence) | (Sequence) | -- | -- |
| access(i) | refused | refused | refused | refused |
| size/count | Y | Y | Y | Y |
| isEmpty | Y | Y | Y | Y |

---

## Outcome

**Status**: RECOMMENDATION

### Coverage

**8 of 12** canonical operations are present (67%). Of the 4 absent:

- **3 are fundamental gaps** (insert_after, delete, splice) that should be added at the primitives layer. These require a cursor or node-handle API and represent the defining linked-list-specific operations that distinguish this data structure from a deque.
- **1 is intentionally refused** (indexed access) -- correct for a linked list.
- **find(x)** is absent by design at the primitives layer due to `Equatable` requirement; partially covered for Copyable elements via `Sequence` conformance.

### Notable Observations

1. **All four variants have identical operation signatures** for the core push/pop/iterate operations. The variants differ in construction, error types, capacity semantics, and protocol conformances -- not in the core operation set.

2. **~Copyable support is comprehensive**. Every mutation and traversal operation works with `~Copyable` elements. The peek/borrowing closure pattern provides non-destructive observation without requiring `Copyable`.

3. **Copyable elements get ergonomic extras**: `first`/`last` properties, `Sequence` conformance (Linked/Bounded only), CoW-safe overloads, `Equatable`/`Hashable`.

4. **Peek API is inconsistent across variants**: Linked and Bounded use `peek.first { }` / `peek.last { }` via Property.View; Inline and Small use `peekFirst { }` / `peekLast { }` as direct methods. Both approaches work, but the inconsistency is noted.

5. **Reverse traversal requires N>=2** (enforced by precondition). This is correctly documented and enforced.

### Action Items

| # | Action | Priority | Notes |
|---|--------|----------|-------|
| 1 | Design cursor/node-handle API | High | Enables insert_after, delete, splice. This is the most impactful missing capability. See `list-discipline-boundary-analysis.md` for design direction and STL/Rust prior art. |
| 2 | Add `splice` (transfer nodes from one list to another) | High | O(1) node transfer. May require shared-arena semantics or arena migration. |
| 3 | Add `split(at:)` (divide list at cursor position) | Medium | O(1) split into two lists at a cursor. Companion to splice. |
| 4 | Consider aligning peek API patterns across variants | Low | Unify on Property.View or direct methods for all variants. |
