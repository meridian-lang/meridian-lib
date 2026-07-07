---
name: order approval
description: Route high-value orders through an account-manager approval gate before shipment.
triggers:
  - "approve high value orders"
  - "route orders for approval"
---

# Order Approval

## When this applies
- "approve high value orders"
- "route orders for approval"

## Workflow
fetch open orders.
for each order whose total amount exceeds the high value threshold:
  wait for approval of the order from an account manager.
  ask the user to choose between "ship", "hold".
  if the choice is "ship",
    ship the order,
  otherwise,
    Note: "order held pending manual review".
Publish: "high value order approval pass complete".

## Report shape
The account manager sees one approval request per high-value order, with a
ship/hold decision recorded for each.
