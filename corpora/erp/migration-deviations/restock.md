# Deviation: restock.meri

- Original: `restock/SKILL.md`
- Ported: `restock.meri`
- Tier: 2 (light edits)
- Similarity: 74%
- Lines: 24 -> 33 (+12 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections inert total: 0/3 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Judgment: 3 blocks, 0 lines

## Unified diff

```diff
--- original-skills/restock/SKILL.md
+++ skills/restock.meri
@@ -8,17 +8,26 @@
 
 # Restock
 
-## Use this when
+## Use this when (( role: procedure ))
+use judgment to follow the Use this when guidance:
 - "restock short products"
 - "inventory below reorder point"
 
 ## Workflow
+use judgment to follow the Workflow guidance:
+Check: any short products.
+
+### Workflow — steps
+
 fetch short products.
-Check: any short products.
+
+### Workflow — steps 2
+
 for each product:
   create a purchase order for the product.
 Publish: "replenishment purchase orders raised".
 
-## Guarantees
+## Guarantees (( role: procedure ))
+use judgment to follow the Guarantees guidance:
 make sure all products have a sku.
 
```
