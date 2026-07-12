# Deviation: orderapproval.meri

- Original: `order_approval/SKILL.md`
- Ported: `orderapproval.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 29 -> 32 (+4 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L22 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 18 non-blank ported lines
- Sections inert total: 1/2 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=18

### Inert section details
- L22 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/order_approval/SKILL.md
+++ skills/orderapproval.meri
@@ -13,6 +13,9 @@
 - "route orders for approval"
 
 ## Workflow
+
+### Workflow — steps
+
 fetch open orders.
 for each order whose total amount exceeds the high value threshold:
   wait for approval of the order from an account manager.
@@ -23,7 +26,7 @@
     Note: "order held pending manual review".
 Publish: "high value order approval pass complete".
 
-## Report shape
+## Report shape (( role: template ))
 The account manager sees one approval request per high-value order, with a
 ship/hold decision recorded for each.
 
```
