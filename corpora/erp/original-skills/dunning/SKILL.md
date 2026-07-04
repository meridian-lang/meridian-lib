---
name: dunning
description: Collect overdue unpaid invoices with deterministic payment attempts.
triggers:
  - "run dunning"
  - "collect overdue invoices"
---

# Dunning

## When operators call this
- "run dunning"
- "collect overdue invoices"

## Workflow
Step: `ofbiz accounting dunning --dry-run --json` to snapshot overdue accounts.
fetch unpaid invoices.
Check: any unpaid invoices.
for each invoice:
  collect payment for the invoice.
Publish: "dunning collection pass complete".

## Controls
Do not contact customers whose account is under manual review.
