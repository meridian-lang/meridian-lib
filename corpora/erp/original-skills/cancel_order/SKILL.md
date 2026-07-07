---
name: cancel order
description: Cancel blocked open orders after deterministic guard checks.
triggers:
  - "cancel blocked orders"
  - "void ERP orders"
---

# Cancel Order

## When this applies
- "cancel blocked orders"
- "void ERP orders"

## Workflow
fetch open orders.
Check: any orders whose status is "blocked".
for each order whose status is "blocked":
  cancel the order unless the order is fulfilled.
Publish: "blocked orders cancelled".

## Controls (( inert, role: invariants ))
An already fulfilled order must not be cancelled by this runbook — already
enforced above by the workflow's own `unless the order is fulfilled` guard;
this line documents the guarantee rather than duplicating it as a second,
separately-attached rule.
