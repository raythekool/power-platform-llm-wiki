---
type: requirement
req_id: REQ-SAL-001
status: certified
owner: Functional team
updated: 2026-09-30
reviewed_by: Jane Analyst
certified_by: John Customer
certified_at: 2026-09-30
sources: [raw/analysis/fdd-sales.md]
tags: [sales, credit]
---

# REQ-SAL-001 Credit check

> Orders above the customer credit limit must be blocked on confirmation.

## Acceptance criteria

1. Confirmation fails when the open balance plus the order total exceeds the credit limit.

## Implementation

- [Plugins](../code/plugins.md)
