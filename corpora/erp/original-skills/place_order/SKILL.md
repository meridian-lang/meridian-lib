---
name: place order
description: Process open ERP orders from reservation through shipment.
triggers:
  - "process open orders"
  - "place customer orders"
---

# Place Order

## When this applies
- "process open orders"
- "place customer orders"

## Operator notes (( inert ))
The source system is an OFBiz-like ERP. Operators think in queues, invoices, and
shipments rather than compiler primitives.

## Workflow (( role: procedure ))
Step: `ofbiz order-check --queue open --json` to snapshot the open order queue.
fetch open orders.
Check: all orders have a number.
Check: no orders whose status is "blocked".
for each order:
  reserve inventory for the order.
  create an invoice for the order.
  collect payment for the invoice.
  ship the order.
Publish: "open order queue processed".

## Checks (( inert, role: invariants ))
No blocked order may pass reservation or shipment release.

## Output (( inert, role: template ))
The operator expects a queue receipt with processed order numbers and shipment
references.
