# List Primitives Scope

## Identity

`swift-list-primitives` provides the **`List` namespace root** for the
linked-list family — the `enum List<Element: ~Copyable>` shell plus the
foundational, stdlib-only declarations and typed-index surface that every
List discipline shares. It is the substrate package that owns the `List`
namespace; the concrete linked-list disciplines compose over it.

## Core targets

- `List Primitive` — the `enum List` namespace root and foundational,
  zero-external-dependency declarations.
- `List Index Primitives` — the `List.Index` typed-index surface
  (`Index_Primitives.Index<Element>`).
- `List Primitives` — the umbrella, re-exporting the root and every
  sub-namespace.

## Out of scope

- The linked-list discipline (`List.Linked` and its `Bounded` / `Inline` /
  `Small` variants, iterators, builders): → `swift-list-linked-primitives`.
- Future non-linked List disciplines that bear their own external
  dependencies: → their own sibling sub-namespace targets or sibling
  packages, never accreted into the zero-dep root.
- `List Primitives Core` is a transitional DEPRECATED shim re-exporting the
  dissolved Core surface; it is removed in the core-dissolution cleanup wave
  and is not part of the package's identity.

## Evaluation rule

Sub-target additions are evaluated against this scope. If a proposed
addition is OUT of scope, it extracts to a sibling package, not into this
one.
