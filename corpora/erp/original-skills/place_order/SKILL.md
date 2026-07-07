---
name: place order
description: Process open ERP orders from reservation through shipment, routing high-value orders for extra scrutiny.
triggers:
  - "process open orders"
  - "place customer orders"
---

# Place Order

## When this applies
- "process open orders"
- "place customer orders"

## Operator notes
The source system is an OFBiz-like ERP. Operators think in queues, invoices, and
shipments rather than compiler primitives.

## Workflow
Step: `ofbiz order-check --queue open --json` to snapshot the open order queue.
fetch open orders.
Check: all orders have a number.
Check: no orders whose status is "blocked".
Check: at most 5 orders whose total amount exceeds the high value threshold.
let top be the first 3 orders sorted by total amount descending.
for each order:
  reserve inventory for the order.
  create an invoice for the order.
  if the order's total amount exceeds the high value threshold,
    verify the order's customer id is not empty,
  otherwise,
    make sure the order's total amount is more than 0.
  collect payment for the invoice.
  recover from payment.declined:
    escalate the invoice.
  ship the order.
Publish: "open order queue processed".

## Checks
No blocked order may pass reservation or shipment release.

## Output
The operator expects a queue receipt with processed order numbers and shipment
references, plus the top 3 orders by total amount.
