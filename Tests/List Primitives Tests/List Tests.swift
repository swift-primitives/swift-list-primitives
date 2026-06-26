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

// NOTE: `List` is a generic namespace (`enum List<Element: ~Copyable>`), so the
// canonical [INST-TEST-013] extension-pattern suite (`extension List { @Suite
// struct Tests {} }`) cannot compile: Swift Testing rejects `@Suite`/`@Test` in a
// generic context (the macro emits a `static let`, which is "not supported in
// generic types"). This top-level, non-compound suite is the closest conforming
// shape; the real suite is authored during flip-prep.
@Suite("List")
struct Tests {
    @Test func `namespace is available`() {
        // Minimal smoke test — the real suite is authored during flip-prep.
        _ = List<Int>.self
        #expect(Bool(true))
    }
}
