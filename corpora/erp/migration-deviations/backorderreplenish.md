# Deviation: backorderreplenish.meri

- Original: `backorder_replenish/SKILL.md`
- Ported: `backorderreplenish.meri`
- Tier: 1 (near-verbatim)
- Similarity: 96%
- Lines: 27 -> 27 (+1 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L17 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=16

### Inert section details
- L17 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/backorder_replenish/SKILL.md
+++ skills/backorderreplenish.meri
@@ -21,7 +21,7 @@
   create a purchase order for the product.
 Publish: "backorder replenishment queued".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states the restock count and calls out the neediest product by
 reorder point.
 
```
