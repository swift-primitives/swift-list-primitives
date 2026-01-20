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

// MARK: - List Tests

@Suite("List")
struct ListTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let list = List<Int>()
        #expect(list.count == 0)
        #expect(list.isEmpty == true)
    }

    @Test("Prepend single element")
    func prependSingle() {
        var list = List<Int>()
        list.prepend(42)
        #expect(list.count == 1)
        #expect(list.isEmpty == false)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Append single element")
    func appendSingle() {
        var list = List<Int>()
        list.append(42)
        #expect(list.count == 1)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Prepend multiple elements")
    func prependMultiple() {
        var list = List<Int>()
        list.prepend(3)
        list.prepend(2)
        list.prepend(1)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Append multiple elements")
    func appendMultiple() {
        var list = List<Int>()
        list.append(1)
        list.append(2)
        list.append(3)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Mixed prepend and append")
    func mixedPrependAppend() {
        var list = List<Int>()
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
        var list = List<Int>()
        let result = list.popFirst()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last from empty")
    func popLastEmpty() {
        var list = List<Int>()
        let result = list.popLast()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first single element")
    func popFirstSingle() {
        var list = List<Int>()
        list.append(42)
        let result = list.popFirst()
        #expect(result == 42)
        #expect(list.isEmpty == true)
        #expect(list.first == nil)
        #expect(list.last == nil)
    }

    @Test("Pop last single element")
    func popLastSingle() {
        var list = List<Int>()
        list.append(42)
        let result = list.popLast()
        #expect(result == 42)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first multiple elements")
    func popFirstMultiple() {
        var list = List<Int>()
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
        var list = List<Int>()
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
        var list = List<Int>()
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
        var list = List<Int>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        list.forEach { collected.append($0) }

        #expect(collected == [1, 2, 3])
    }

    @Test("ForEach reversed")
    func forEachReversed() {
        var list = List<Int>()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        list.forEachReversed { collected.append($0) }

        #expect(collected == [3, 2, 1])
    }

    @Test("Sequence iteration")
    func sequenceIteration() {
        var list = List<Int>()
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
        var list = List<Int>()
        list.append(1)
        list.append(2)
        list.append(3)

        let array = Array(list)
        #expect(array == [1, 2, 3])
    }

    @Test("Equality")
    func equality() {
        var list1 = List<Int>()
        list1.append(1)
        list1.append(2)
        list1.append(3)

        var list2 = List<Int>()
        list2.append(1)
        list2.append(2)
        list2.append(3)

        var list3 = List<Int>()
        list3.append(1)
        list3.append(2)
        list3.append(4)

        #expect(list1 == list2)
        #expect(list1 != list3)
    }

    @Test("Equality different lengths")
    func equalityDifferentLengths() {
        var list1 = List<Int>()
        list1.append(1)
        list1.append(2)

        var list2 = List<Int>()
        list2.append(1)
        list2.append(2)
        list2.append(3)

        #expect(list1 != list2)
    }
}

// MARK: - List.Singly Tests

@Suite("List.Singly")
struct ListSinglyTests {

    @Test("Initialize empty")
    func initializeEmpty() {
        let list = List<Int>.Singly()
        #expect(list.count == 0)
        #expect(list.isEmpty == true)
    }

    @Test("Prepend single element")
    func prependSingle() {
        var list = List<Int>.Singly()
        list.prepend(42)
        #expect(list.count == 1)
        #expect(list.isEmpty == false)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Append single element")
    func appendSingle() {
        var list = List<Int>.Singly()
        list.append(42)
        #expect(list.count == 1)
        #expect(list.first == 42)
        #expect(list.last == 42)
    }

    @Test("Prepend multiple elements")
    func prependMultiple() {
        var list = List<Int>.Singly()
        list.prepend(3)
        list.prepend(2)
        list.prepend(1)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Append multiple elements")
    func appendMultiple() {
        var list = List<Int>.Singly()
        list.append(1)
        list.append(2)
        list.append(3)
        #expect(list.count == 3)
        #expect(list.first == 1)
        #expect(list.last == 3)
    }

    @Test("Pop first from empty")
    func popFirstEmpty() {
        var list = List<Int>.Singly()
        let result = list.popFirst()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last from empty")
    func popLastEmpty() {
        var list = List<Int>.Singly()
        let result = list.popLast()
        #expect(result == nil)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first single element")
    func popFirstSingle() {
        var list = List<Int>.Singly()
        list.append(42)
        let result = list.popFirst()
        #expect(result == 42)
        #expect(list.isEmpty == true)
    }

    @Test("Pop last single element")
    func popLastSingle() {
        var list = List<Int>.Singly()
        list.append(42)
        let result = list.popLast()
        #expect(result == 42)
        #expect(list.isEmpty == true)
    }

    @Test("Pop first multiple elements")
    func popFirstMultiple() {
        var list = List<Int>.Singly()
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
        var list = List<Int>.Singly()
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
        var list = List<Int>.Singly()
        list.append(1)
        list.append(2)
        list.append(3)

        list.clear()

        #expect(list.isEmpty == true)
        #expect(list.count == 0)
    }

    @Test("ForEach")
    func forEach() {
        var list = List<Int>.Singly()
        list.append(1)
        list.append(2)
        list.append(3)

        var collected: [Int] = []
        list.forEach { collected.append($0) }

        #expect(collected == [1, 2, 3])
    }

    @Test("Sequence iteration")
    func sequenceIteration() {
        var list = List<Int>.Singly()
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
        var list1 = List<Int>.Singly()
        list1.append(1)
        list1.append(2)
        list1.append(3)

        var list2 = List<Int>.Singly()
        list2.append(1)
        list2.append(2)
        list2.append(3)

        var list3 = List<Int>.Singly()
        list3.append(1)
        list3.append(2)
        list3.append(4)

        #expect(list1 == list2)
        #expect(list1 != list3)
    }
}
