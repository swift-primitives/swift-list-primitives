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
import List_Primitives_Test_Support

@testable import List_Primitives

// MARK: - List.Linked<2> Tests (Doubly-Linked)

@Suite("List.Linked<2> (Doubly-Linked)")
struct ListLinkedDoublyTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let list = List<Int>.Linked<2>()
        #expect(list.count == 0)
        #expect(list.isEmpty == true)
    }

    @Test("Prepend single element")
    func prependSingle() {
        var list = List<Int>.Linked<2>()
        list.prepend(42)
        #expect(list.count == 1)
        #expect(list.isEmpty == false)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Append single element")
    func appendSingle() {
        var list = List<Int>.Linked<2>()
        list.append(42)
        #expect(list.count == 1)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Prepend multiple elements")
    func prependMultiple() {
        var list = List<Int>.Linked<2>()
        list.prepend(3)
        list.prepend(2)
        list.prepend(1)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Append multiple elements")
    func appendMultiple() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Mixed prepend and append")
    func mixedPrependAppend() {
        var list = List<Int>.Linked<2>()
        list.append(2)
        list.prepend(1)
        list.append(3)
        list.prepend(0)
        // Order: 0, 1, 2, 3
        #expect(list.count == 4)
        #expect(list.first == 0)
        #expect(list.last == 3)
    }

    @Test("Pop first from empty")
    func popFirstEmpty() {
        var list = List<Int>.Linked<2>()
        let result = list.popFirst()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last from empty")
    func popLastEmpty() {
        var list = List<Int>.Linked<2>()
        let result = list.popLast()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first single element")
    func popFirstSingle() {
        var list = List<Int>.Linked<2>()
        list.append(42)
        let result = list.popFirst()
        #expect(result == 42)
        #expect(list.isEmpty == true)
        #expect(list.first == nil)
        #expect(list.last == nil)
    }

    @Test("Pop last single element")
    func popLastSingle() {
        var list = List<Int>.Linked<2>()
        list.append(42)
        let result = list.popLast()
        #expect(result == 42)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first multiple elements")
    func popFirstMultiple() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)

        #expect(list.popFirst() == 1)
        #expect(list.count == 2)
        #expect(list.first == 2)

        #expect(list.popFirst() == 2)
        #expect(list.count == 1)

        #expect(list.popFirst() == 3)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last multiple elements")
    func popLastMultiple() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)

        #expect(list.popLast() == 3)
        #expect(list.count == 2)
        #expect(list.last == 2)

        #expect(list.popLast() == 2)
        #expect(list.count == 1)

        #expect(list.popLast() == 1)
        #expect(list.isEmpty == true)
    }

    @Test("Clear")
    func clear() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)

        list.clear()

        #expect(list.isEmpty == true)
        #expect(list.count == 0)
        #expect(list.first == nil)
        #expect(list.last == nil)
    }

    @Test("ForEach")
    func forEach() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        list.forEach { collected.append($0) }

        #expect(collected == [1, 2, 3])
    }

    @Test("Reversed forEach")
    func reversedForEach() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        list.reversed.forEach { collected.append($0) }

        #expect(collected == [3, 2, 1])
    }

    @Test("Sequence iteration")
    func sequenceIteration() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        for element in list {
            collected.append(element)
        }

        #expect(collected == [1, 2, 3])
    }

    @Test("Array conversion")
    func arrayConversion() {
        var list = List<Int>.Linked<2>()
        list.append(1)
        list.append(2)
        list.append(3)

        let array = Array(list)
        #expect(array == [1, 2, 3])
    }

    @Test("Equality")
    func equality() {
        var list1 = List<Int>.Linked<2>()
        list1.append(1)
        list1.append(2)
        list1.append(3)

        var list2 = List<Int>.Linked<2>()
        list2.append(1)
        list2.append(2)
        list2.append(3)

        var list3 = List<Int>.Linked<2>()
        list3.append(1)
        list3.append(2)
        list3.append(4)

        #expect(list1 == list2)
        #expect(list1 != list3)
    }

    @Test("Equality different lengths")
    func equalityDifferentLengths() {
        var list1 = List<Int>.Linked<2>()
        list1.append(1)
        list1.append(2)

        var list2 = List<Int>.Linked<2>()
        list2.append(1)
        list2.append(2)
        list2.append(3)

        #expect(list1 != list2)
    }
}

// MARK: - List.Linked<1> Tests (Singly-Linked)

@Suite("List.Linked<1> (Singly-Linked)")
struct ListLinkedSinglyTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let list = List<Int>.Linked<1>()
        #expect(list.count == 0)
        #expect(list.isEmpty == true)
    }

    @Test("Prepend single element")
    func prependSingle() {
        var list = List<Int>.Linked<1>()
        list.prepend(42)
        #expect(list.count == 1)
        #expect(list.isEmpty == false)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Append single element")
    func appendSingle() {
        var list = List<Int>.Linked<1>()
        list.append(42)
        #expect(list.count == 1)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Prepend multiple elements")
    func prependMultiple() {
        var list = List<Int>.Linked<1>()
        list.prepend(3)
        list.prepend(2)
        list.prepend(1)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Append multiple elements")
    func appendMultiple() {
        var list = List<Int>.Linked<1>()
        list.append(1)
        list.append(2)
        list.append(3)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Pop first from empty")
    func popFirstEmpty() {
        var list = List<Int>.Linked<1>()
        let result = list.popFirst()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last from empty")
    func popLastEmpty() {
        var list = List<Int>.Linked<1>()
        let result = list.popLast()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first single element")
    func popFirstSingle() {
        var list = List<Int>.Linked<1>()
        list.append(42)
        let result = list.popFirst()
        #expect(result == 42)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last single element")
    func popLastSingle() {
        var list = List<Int>.Linked<1>()
        list.append(42)
        let result = list.popLast()
        #expect(result == 42)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first multiple elements")
    func popFirstMultiple() {
        var list = List<Int>.Linked<1>()
        list.append(1)
        list.append(2)
        list.append(3)

        #expect(list.popFirst() == 1)
        #expect(list.count == 2)
        #expect(list.first == 2)

        #expect(list.popFirst() == 2)
        #expect(list.count == 1)

        #expect(list.popFirst() == 3)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last multiple elements (O(n) traversal)")
    func popLastMultiple() {
        var list = List<Int>.Linked<1>()
        list.append(1)
        list.append(2)
        list.append(3)

        #expect(list.popLast() == 3)
        #expect(list.count == 2)
        #expect(list.last == 2)

        #expect(list.popLast() == 2)
        #expect(list.count == 1)

        #expect(list.popLast() == 1)
        #expect(list.isEmpty == true)
    }

    @Test("Clear")
    func clear() {
        var list = List<Int>.Linked<1>()
        list.append(1)
        list.append(2)
        list.append(3)

        list.clear()

        #expect(list.isEmpty == true)
        #expect(list.count == 0)
    }

    @Test("ForEach")
    func forEach() {
        var list = List<Int>.Linked<1>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        list.forEach { collected.append($0) }

        #expect(collected == [1, 2, 3])
    }

    @Test("Sequence iteration")
    func sequenceIteration() {
        var list = List<Int>.Linked<1>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        for element in list {
            collected.append(element)
        }

        #expect(collected == [1, 2, 3])
    }

    @Test("Equality")
    func equality() {
        var list1 = List<Int>.Linked<1>()
        list1.append(1)
        list1.append(2)
        list1.append(3)

        var list2 = List<Int>.Linked<1>()
        list2.append(1)
        list2.append(2)
        list2.append(3)

        var list3 = List<Int>.Linked<1>()
        list3.append(1)
        list3.append(2)
        list3.append(4)

        #expect(list1 == list2)
        #expect(list1 != list3)
    }
}

// MARK: - List.Linked.Bounded Tests

@Suite("List.Linked.Bounded")
struct ListLinkedBoundedTests {

    @Test("Initialize with capacity")
    func initializeWithCapacity() throws {
        let list = try List<Int>.Linked<2>.Bounded(capacity: 10)
        #expect(list.count == 0)
        #expect(list.isEmpty == true)
        #expect(list.capacity == 10)
        #expect(list.isFull == false)
    }

    @Test("Prepend and append")
    func prependAndAppend() throws {
        var list = try List<Int>.Linked<2>.Bounded(capacity: 5)
        try list.prepend(2)
        try list.prepend(1)
        try list.append(3)

        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Overflow on prepend")
    func overflowOnPrepend() throws {
        var list = try List<Int>.Linked<2>.Bounded(capacity: 2)
        try list.prepend(1)
        try list.prepend(2)

        #expect(list.isFull == true)

        #expect(throws: __ListLinkedBoundedError.overflow) {
            try list.prepend(3)
        }
    }

    @Test("Overflow on append")
    func overflowOnAppend() throws {
        var list = try List<Int>.Linked<2>.Bounded(capacity: 2)
        try list.append(1)
        try list.append(2)

        #expect(list.isFull == true)

        #expect(throws: __ListLinkedBoundedError.overflow) {
            try list.append(3)
        }
    }

    @Test("Pop after overflow allows new elements")
    func popAfterOverflow() throws {
        var list = try List<Int>.Linked<2>.Bounded(capacity: 2)
        try list.append(1)
        try list.append(2)

        _ = list.popFirst()

        try list.append(3)
        #expect(list.count == 2)
    }

    @Test("Sequence iteration")
    func sequenceIteration() throws {
        var list = try List<Int>.Linked<2>.Bounded(capacity: 5)
        try list.append(1)
        try list.append(2)
        try list.append(3)

        var collected: [Int] = []
        for element in list {
            collected.append(element)
        }

        #expect(collected == [1, 2, 3])
    }
}

// MARK: - List.Linked.Inline Tests

@Suite("List.Linked.Inline")
struct ListLinkedInlineTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let list = List<Int>.Linked<2>.Inline<8>()
        #expect(list.count == 0)
        #expect(list.isEmpty == true)
        #expect(list.isFull == false)
    }

    @Test("Prepend and append")
    func prependAndAppend() throws {
        var list = List<Int>.Linked<2>.Inline<8>()
        try list.prepend(2)
        try list.prepend(1)
        try list.append(3)

        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Overflow on prepend")
    func overflowOnPrepend() throws {
        var list = List<Int>.Linked<2>.Inline<2>()
        try list.prepend(1)
        try list.prepend(2)

        #expect(list.isFull == true)

        #expect(throws: __ListLinkedInlineError.overflow) {
            try list.prepend(3)
        }
    }

    @Test("Pop operations")
    func popOperations() throws {
        var list = List<Int>.Linked<2>.Inline<8>()
        try list.append(1)
        try list.append(2)
        try list.append(3)

        #expect(list.popFirst() == 1)
        #expect(list.popLast() == 3)
        #expect(list.count == 1)
        #expect(list.first == 2)
    }

    @Test("ForEach")
    func forEach() throws {
        var list = List<Int>.Linked<2>.Inline<8>()
        try list.append(1)
        try list.append(2)
        try list.append(3)

        var collected: [Int] = []
        list.forEach { collected.append($0) }

        #expect(collected == [1, 2, 3])
    }

    // Note: Inline does not conform to Sequence (unconditionally ~Copyable)
    // Use forEach for iteration instead
}

// MARK: - List.Linked.Small Tests

@Suite("List.Linked.Small")
struct ListLinkedSmallTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let list = List<Int>.Linked<2>.Small<4>()
        #expect(list.count == 0)
        #expect(list.isEmpty == true)
        #expect(list.isSpilled == false)
    }

    @Test("Inline storage")
    func inlineStorage() {
        var list = List<Int>.Linked<2>.Small<4>()
        list.prepend(2)
        list.prepend(1)
        list.append(3)

        #expect(list.count == 3)
        #expect(list.isSpilled == false)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Spill to heap")
    func spillToHeap() {
        var list = List<Int>.Linked<2>.Small<4>()
        list.append(1)
        list.append(2)
        list.append(3)
        list.append(4)

        #expect(list.isSpilled == false)

        list.append(5)  // This should spill to heap

        #expect(list.isSpilled == true)
        #expect(list.count == 5)
        #expect(list.first == 1)
        #expect(list.last == 5)
    }

    @Test("Pop operations after spill")
    func popOperationsAfterSpill() {
        var list = List<Int>.Linked<2>.Small<2>()
        list.append(1)
        list.append(2)
        list.append(3)  // Spills to heap

        #expect(list.isSpilled == true)

        #expect(list.popFirst() == 1)
        #expect(list.popLast() == 3)
        #expect(list.count == 1)
        #expect(list.first == 2)
    }

    @Test("ForEach")
    func forEach() {
        var list = List<Int>.Linked<2>.Small<4>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        list.forEach { collected.append($0) }

        #expect(collected == [1, 2, 3])
    }

    @Test("ForEach after spill")
    func forEachAfterSpill() {
        var list = List<Int>.Linked<2>.Small<2>()
        list.append(1)
        list.append(2)
        list.append(3)  // Spills to heap

        var collected: [Int] = []
        list.forEach { collected.append($0) }

        #expect(collected == [1, 2, 3])
    }

    // Note: Small does not conform to Sequence (unconditionally ~Copyable)
    // Use forEach for iteration instead

    @Test("Clear")
    func clear() {
        var list = List<Int>.Linked<2>.Small<2>()
        list.append(1)
        list.append(2)
        list.append(3)  // Spills to heap

        list.clear()

        #expect(list.isEmpty == true)
        #expect(list.count == 0)
        #expect(list.isSpilled == false)
    }
}

// MARK: - Stress Tests

/// A class that tracks init/deinit counts for detecting leaks and double-destroys.
private final class DeinitCounter: @unchecked Sendable {
    static let shared = DeinitCounter()
    var initCount = 0
    var deinitCount = 0

    func reset() {
        initCount = 0
        deinitCount = 0
    }
}

/// A test element that tracks its lifetime via DeinitCounter.
private final class TrackedElement: @unchecked Sendable {
    let value: Int

    init(_ value: Int) {
        self.value = value
        DeinitCounter.shared.initCount += 1
    }

    deinit {
        DeinitCounter.shared.deinitCount += 1
    }
}

@Suite("List.Linked Stress Tests")
struct ListLinkedStressTests {

    @Test("Free-list reuse cycle")
    func freeListReuseCycle() {
        // Push N elements, pop half, push half again, repeat
        var list = List<Int>.Linked<2>()

        for round in 0..<10 {
            // Push 10 elements
            for i in 0..<10 {
                list.append(round * 100 + i)
            }
            #expect(list.count == 10)

            // Pop first 5
            for i in 0..<5 {
                let popped = list.popFirst()
                #expect(popped == round * 100 + i)
            }
            #expect(list.count == 5)

            // Push 5 more (should reuse freed slots)
            for i in 0..<5 {
                list.append(round * 100 + 10 + i)
            }
            #expect(list.count == 10)

            // Verify ordering
            var expected = [Int]()
            for i in 5..<10 {
                expected.append(round * 100 + i)
            }
            for i in 0..<5 {
                expected.append(round * 100 + 10 + i)
            }
            var collected = [Int]()
            list.forEach { collected.append($0) }
            #expect(collected == expected)

            // Clear for next round
            list.clear()
        }
    }

    @Test("Growth with live nodes")
    func growthWithLiveNodes() {
        // Start with small capacity, force multiple growths
        var list = List<Int>.Linked<2>()

        // Append enough to trigger growth multiple times
        for i in 0..<100 {
            list.append(i)
        }
        #expect(list.count == 100)

        // Verify all elements
        var collected = [Int]()
        list.forEach { collected.append($0) }
        #expect(collected == Array(0..<100))

        // Interleave pops and appends
        for i in 0..<50 {
            let popped = list.popFirst()
            #expect(popped == i)
            list.append(100 + i)
        }
        #expect(list.count == 100)

        // Verify new state
        collected = []
        list.forEach { collected.append($0) }
        #expect(collected == Array(50..<100) + Array(100..<150))
    }

    @Test("CoW correctness")
    func cowCorrectness() {
        // Create list A with items
        var listA = List<Int>.Linked<2>()
        listA.append(1)
        listA.append(2)
        listA.append(3)

        // Copy to B
        var listB = listA

        // Mutate B
        listB.append(4)
        listB.popFirst()

        // Verify A unchanged
        #expect(listA.count == 3)
        #expect(Array(listA) == [1, 2, 3])

        // Verify B has mutations
        #expect(listB.count == 3)
        #expect(Array(listB) == [2, 3, 4])

        // Further mutations on both
        listA.append(10)
        listB.append(20)

        #expect(Array(listA) == [1, 2, 3, 10])
        #expect(Array(listB) == [2, 3, 4, 20])
    }

    @Test("No leaks or double-destroys")
    func noLeaksOrDoubleDestroys() {
        DeinitCounter.shared.reset()

        do {
            var list = List<TrackedElement>.Linked<2>()
            list.append(TrackedElement(1))
            list.append(TrackedElement(2))
            list.append(TrackedElement(3))
            #expect(DeinitCounter.shared.initCount == 3)

            // Pop one
            _ = list.popFirst()
            #expect(DeinitCounter.shared.deinitCount == 1)

            // Add more (should reuse slot)
            list.append(TrackedElement(4))
            list.append(TrackedElement(5))
            #expect(DeinitCounter.shared.initCount == 5)

            // Clear
            list.clear()
            #expect(DeinitCounter.shared.deinitCount == 5)
        }

        // After scope, all should be deinitialized
        #expect(DeinitCounter.shared.initCount == DeinitCounter.shared.deinitCount)
    }

    @Test("Rapid push-pop cycle (free-list torture)")
    func rapidPushPopCycle() {
        // ChatGPT's specific test: capacity 1-2, force growth + free-list reuse
        var list = List<Int>.Linked<2>()

        for round in 0..<100 {
            // Append 3 elements (forces growth quickly)
            list.append(round * 10)
            list.append(round * 10 + 1)
            list.append(round * 10 + 2)

            // Pop first (frees a slot)
            let popped = list.popFirst()
            #expect(popped == round * 10)

            // Append again (allocates from free list)
            list.append(round * 10 + 3)

            // Verify count
            #expect(list.count == 3)

            // Clear for next round
            list.clear()
        }
    }

    @Test("Bounded free-list reuse")
    func boundedFreeListReuse() throws {
        var list = try List<Int>.Linked<2>.Bounded(capacity: 5)

        // Fill to capacity
        for i in 0..<5 {
            try list.append(i)
        }
        #expect(list.isFull)

        // Pop all
        for i in 0..<5 {
            #expect(list.popFirst() == i)
        }
        #expect(list.isEmpty)

        // Fill again (should reuse freed slots)
        for i in 10..<15 {
            try list.append(i)
        }
        #expect(list.isFull)

        // Verify
        var collected = [Int]()
        list.forEach { collected.append($0) }
        #expect(collected == Array(10..<15))
    }
}

// MARK: - Singly-Linked Variants

@Suite("List.Linked<1> Variants")
struct ListLinkedSinglyVariantsTests {

    @Test("Bounded singly-linked")
    func boundedSinglyLinked() throws {
        var list = try List<Int>.Linked<1>.Bounded(capacity: 5)
        try list.prepend(2)
        try list.prepend(1)
        try list.append(3)  // O(n) for singly-linked

        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)

        // popLast is O(n) for singly-linked
        #expect(list.popLast() == 3)
        #expect(list.count == 2)
    }

    @Test("Inline singly-linked")
    func inlineSinglyLinked() throws {
        var list = List<Int>.Linked<1>.Inline<8>()
        try list.prepend(2)
        try list.prepend(1)
        try list.append(3)

        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Small singly-linked with spill")
    func smallSinglyLinkedWithSpill() {
        var list = List<Int>.Linked<1>.Small<2>()
        list.append(1)
        list.append(2)

        #expect(list.isSpilled == false)

        list.append(3)  // Spills to heap

        #expect(list.isSpilled == true)
        #expect(list.count == 3)

        // popLast is O(n) for singly-linked
        #expect(list.popLast() == 3)
        #expect(list.count == 2)
    }
}
