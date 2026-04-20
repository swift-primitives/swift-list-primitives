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

import Testing
@testable import List_Primitives

@Suite("List - Deinit")
struct ListDeinitTests {

    final class Tracker: @unchecked Sendable {
        private var _storage: [Int] = []
        var deinitCount: Int { _storage.count }
        var deinitOrder: [Int] { _storage }
        func append(_ id: Int) { _storage.append(id) }
    }

    struct TrackedElement: ~Copyable {
        let id: Int
        let tracker: Tracker
        init(_ id: Int, tracker: Tracker) { self.id = id; self.tracker = tracker }
        deinit { tracker.append(id) }
    }

    // MARK: - List.Linked.Inline (doubly-linked, N=2)

    @Test
    func `Inline deinit destroys all elements`() throws {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<2>.Inline<8>()
            try list.prepend(TrackedElement(1, tracker: tracker))
            try list.prepend(TrackedElement(2, tracker: tracker))
            try list.prepend(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Inline deinit after partial pop destroys remaining`() throws {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<2>.Inline<8>()
            try list.append(TrackedElement(1, tracker: tracker))
            try list.append(TrackedElement(2, tracker: tracker))
            try list.append(TrackedElement(3, tracker: tracker))
            _ = list.popFirst()
            #expect(tracker.deinitCount == 1)
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Inline empty deinit does not crash`() {
        do {
            _ = List<TrackedElement>.Linked<2>.Inline<8>()
        }
    }

    @Test
    func `Inline singly-linked deinit destroys all elements`() throws {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<1>.Inline<8>()
            try list.prepend(TrackedElement(1, tracker: tracker))
            try list.prepend(TrackedElement(2, tracker: tracker))
            try list.prepend(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    // MARK: - List.Linked.Small (doubly-linked, N=2)

    @Test
    func `Small deinit destroys all elements in inline mode`() {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<2>.Small<4>()
            list.prepend(TrackedElement(1, tracker: tracker))
            list.prepend(TrackedElement(2, tracker: tracker))
            list.prepend(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Small deinit destroys all elements after spill`() {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<2>.Small<2>()
            list.prepend(TrackedElement(1, tracker: tracker))
            list.prepend(TrackedElement(2, tracker: tracker))
            // Spill to heap
            list.prepend(TrackedElement(3, tracker: tracker))
            list.prepend(TrackedElement(4, tracker: tracker))
        }
        #expect(tracker.deinitCount == 4)
    }

    @Test
    func `Small deinit after partial pop destroys remaining`() {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<2>.Small<4>()
            list.append(TrackedElement(1, tracker: tracker))
            list.append(TrackedElement(2, tracker: tracker))
            list.append(TrackedElement(3, tracker: tracker))
            _ = list.popFirst()
            #expect(tracker.deinitCount == 1)
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Small deinit after spill and partial pop destroys remaining`() {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<2>.Small<2>()
            list.append(TrackedElement(1, tracker: tracker))
            list.append(TrackedElement(2, tracker: tracker))
            list.append(TrackedElement(3, tracker: tracker))
            list.append(TrackedElement(4, tracker: tracker))
            #expect(list.isSpilled == true)
            _ = list.popFirst()
            _ = list.popFirst()
            #expect(tracker.deinitCount == 2)
        }
        #expect(tracker.deinitCount == 4)
    }

    @Test
    func `Small empty deinit does not crash`() {
        do {
            _ = List<TrackedElement>.Linked<2>.Small<4>()
        }
    }

    @Test
    func `Small singly-linked deinit destroys all elements`() {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<1>.Small<4>()
            list.prepend(TrackedElement(1, tracker: tracker))
            list.prepend(TrackedElement(2, tracker: tracker))
            list.prepend(TrackedElement(3, tracker: tracker))
        }
        #expect(tracker.deinitCount == 3)
    }

    @Test
    func `Small singly-linked deinit destroys all elements after spill`() {
        let tracker = Tracker()
        do {
            var list = List<TrackedElement>.Linked<1>.Small<2>()
            list.append(TrackedElement(1, tracker: tracker))
            list.append(TrackedElement(2, tracker: tracker))
            list.append(TrackedElement(3, tracker: tracker))
            list.append(TrackedElement(4, tracker: tracker))
            #expect(list.isSpilled == true)
        }
        #expect(tracker.deinitCount == 4)
    }
}
