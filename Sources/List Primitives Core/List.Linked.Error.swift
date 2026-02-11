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

// MARK: - Hoisted Error Types (Module Level)
//
// Swift does not allow nested types inside generic types to be easily accessed.
// These error types are hoisted to module level and exposed via typealiases to
// provide the expected Nest.Name API (List.Linked.Error, etc.).
//
// This is a documented exception per [API-EXC-001] due to Swift language
// limitations with generic nested types.
//
// Use the typealias forms in your code:
// - List<Element>.Linked<N>.Error
// - List<Element>.Linked<N>.Bounded.Error
// - List<Element>.Linked<N>.Inline.Error
// - List<Element>.Linked<N>.Small.Error

/// Hoisted implementation of ``List/Linked/Error``.
///
/// - Note: Use ``List/Linked/Error`` in your code, not this type directly.
public enum __ListLinkedError: Swift.Error, Sendable, Equatable {
    /// The list is empty and the operation requires elements.
    case empty

    /// The requested capacity is invalid (negative).
    case invalidCapacity
}

/// Hoisted implementation of ``List/Linked/Bounded/Error``.
///
/// - Note: Use ``List/Linked/Bounded/Error`` in your code, not this type directly.
public enum __ListLinkedBoundedError: Swift.Error, Sendable, Equatable {
    /// The list is empty and the operation requires elements.
    case empty

    /// The requested capacity is invalid (negative).
    case invalidCapacity

    /// The list is full and cannot accept more elements.
    case overflow
}

/// Hoisted implementation of ``List/Linked/Inline/Error``.
///
/// - Note: Use ``List/Linked/Inline/Error`` in your code, not this type directly.
public enum __ListLinkedInlineError: Swift.Error, Sendable, Equatable {
    /// The list is empty and the operation requires elements.
    case empty

    /// The list is full and cannot accept more elements.
    case overflow
}

/// Hoisted implementation of ``List/Linked/Small/Error``.
///
/// - Note: Use ``List/Linked/Small/Error`` in your code, not this type directly.
public enum __ListLinkedSmallError: Swift.Error, Sendable, Equatable {
    /// The list is empty and the operation requires elements.
    case empty
}

// MARK: - Typealiases (Nest.Name API)
//
// IMPORTANT: Extensions MUST include `where Element: ~Copyable` to prevent
// implicit Copyable constraint. This is a documented Swift compiler limitation.
// See [MEM-COPY-004].

extension List.Linked where Element: ~Copyable {
    /// Errors that can occur during linked list operations.
    ///
    /// ## Cases
    ///
    /// - ``Error/empty``: The list is empty and the operation requires elements.
    /// - ``Error/invalidCapacity``: The requested capacity is invalid (negative).
    public typealias Error = __ListLinkedError
}

extension List.Linked.Bounded where Element: ~Copyable {
    /// Errors that can occur during bounded linked list operations.
    ///
    /// ## Cases
    ///
    /// - ``Error/empty``: The list is empty and the operation requires elements.
    /// - ``Error/invalidCapacity``: The requested capacity is invalid (negative).
    /// - ``Error/overflow``: The list is full and cannot accept more elements.
    public typealias Error = __ListLinkedBoundedError
}

extension List.Linked.Inline where Element: Copyable {
    /// Errors that can occur during inline linked list operations.
    ///
    /// ## Cases
    ///
    /// - ``Error/empty``: The list is empty and the operation requires elements.
    /// - ``Error/overflow``: The list is full and cannot accept more elements.
    public typealias Error = __ListLinkedInlineError
}

extension List.Linked.Small where Element: Copyable {
    /// Errors that can occur during small linked list operations.
    ///
    /// ## Cases
    ///
    /// - ``Error/empty``: The list is empty and the operation requires elements.
    public typealias Error = __ListLinkedSmallError
}
