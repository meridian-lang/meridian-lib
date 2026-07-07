---
name: restock
description: Raise replenishment purchase orders for short products.
triggers:
  - "restock short products"
  - "inventory below reorder point"
---

# Restock

## Use this when
- "restock short products"
- "inventory below reorder point"

## Workflow
fetch short products.
Check: any short products.
Check: at most 20 short products.
for each product:
  create a purchase order for the product.
Publish: "replenishment purchase orders raised".

## Guarantees
make sure all products have a sku.
guarantee that all purchase orders whose status is "pending" have a number.
