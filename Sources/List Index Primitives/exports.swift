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

// List Index Primitives owns the `List.Index` typed-index surface, which is
// defined in terms of `Index_Primitives.Index<Element>`. This sub-namespace
// declares `Index_Primitives` directly per [MOD-002] (amended) / [MOD-031];
// the former package-level funnel re-exported it from the dissolved Core.

@_exported public import Index_Primitives
