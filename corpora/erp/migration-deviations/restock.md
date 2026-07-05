# Deviation: restock.meri

- Original: `restock/SKILL.md`
- Ported: `restock.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 24 -> 30 (+8 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/restock/SKILL.md
+++ skills/restock.meri
@@ -12,9 +12,15 @@
 - "restock short products"
 - "inventory below reorder point"
 
-## Workflow
+## Workflow (( role: reference ))
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
```
