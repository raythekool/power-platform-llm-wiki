---
type: code
status: draft
updated: 2026-09-30
implements: [REQ-SAL-001]
sources: [raw/code/contoso-sales-2026-09-30.json]
tags: [plugin]
---

# Plugins

> Dataverse plugins of the Contoso solution.

## Credit check plugin

`CreditCheckPlugin` runs on `salesorder` update (pre-operation) and implements [REQ-SAL-001](../requirements/REQ-SAL-001-credit-check.md#acceptance-criteria).

```mermaid
sequenceDiagram
    participant U as User
    participant P as CreditCheckPlugin
    U->>P: Confirm order
    P-->>U: Error when limit exceeded
```

## Diagram

![Flow](../assets/flow.png)
