# Audit: swift-list-primitives

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/audit-primitives.md (2026-04-03)

**Pre-publication dependency-tree audit — P0/P1/P2 checks**

#### P1: Multi-Type File [API-IMPL-005]

**File**: `Sources/List Primitives Core/List.Linked.Error.swift` (4 types, 115 lines)

| Line | Type |
|------|------|
| 30 | `__ListLinkedError` |
| 41 | `__ListLinkedBoundedError` |
| 55 | `__ListLinkedInlineError` |
| 66 | `__ListLinkedSmallError` |

**Assessment**: `__`-prefixed internal error enums hoisted to module scope for typed throws. Grouping is justified: related error types for variants of the same data structure sharing documentation context.

**Recommendation**: Accept as-is. The `__` prefix signals implementation infrastructure, not public API surface.

---

### From: swift-institute/Research/audits/implementation-naming-2026-03-20/swift-data-structures-batch.md (2026-03-20)

**Implementation + naming audit**

CLEAN - no findings
