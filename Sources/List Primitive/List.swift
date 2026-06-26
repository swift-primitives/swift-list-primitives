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

/// Root namespace for the package's list-discipline primitives.
///
/// `List` is an empty generic enum that serves as the shared namespace for
/// every list discipline in the package. The `Element` parameter is carried by
/// the namespace itself — and may be `~Copyable` — so that nested disciplines
/// and the typed-index surface in `List Index Primitives` agree on a single
/// element type.
///
/// This target retains only the namespace shell and its foundational,
/// stdlib-only declarations. The linked-list discipline — `List.Linked` and its
/// `Bounded`, `Inline`, and `Small` variants — was extracted to
/// `swift-list-linked-primitives`; future zero-dependency list disciplines are
/// declared here.
public enum List<Element: ~Copyable> {}
