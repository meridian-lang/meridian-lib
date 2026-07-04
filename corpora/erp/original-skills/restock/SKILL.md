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

## Workflow (( role: procedure ))
fetch short products.
Check: any short products.
for each product:
  create a purchase order for the product.
Publish: "replenishment purchase orders raised".

## Guarantees (( role: invariants ))
make sure all products have a sku.
