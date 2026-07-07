---
name: fulfill order
description: Release fulfilled ERP orders after reservation and shipment checks.
triggers:
  - "fulfill ERP orders"
  - "release shipments"
---

# Fulfill Order

## When this applies
- "fulfill ERP orders"
- "release shipments"

## Operator notes
Warehouse operators say "release the shipment" rather than "invoke the
fulfillment workflow." This skill keeps that vocabulary while compiling to
declared tool calls.

## Workflow
Step: `ofbiz shipment --pending --json` to capture pending warehouse work.
fetch open orders.
Check: all orders have a number.
for each order:
  reserve inventory for the order.
  if the order is high value,
    wait for approval of the order from an account manager,
  otherwise,
    make sure the order's total amount is more than 0.
  ship the order.
Publish: "shipment release queue drained".

## Checks
Every released order has inventory reserved.
