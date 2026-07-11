# Deviation: fulfillorder.meri

- Original: `fulfill_order/SKILL.md`
- Ported: `fulfillorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 35 -> 38 (+4 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Operator notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=3, structure=0, desugar=0, meaning=24

### Inert section details
- L8 `Operator notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/fulfill_order/SKILL.md
+++ skills/fulfillorder.meri
@@ -12,12 +12,15 @@
 - "fulfill ERP orders"
 - "release shipments"
 
-## Operator notes
+## Operator notes (( role: reference ))
 Warehouse operators say "release the shipment" rather than "invoke the
 fulfillment workflow." This skill keeps that vocabulary while compiling to
 declared tool calls.
 
 ## Workflow
+
+### Workflow — steps
+
 Step: `ofbiz shipment --pending --json` to capture pending warehouse work.
 fetch open orders.
 Check: all orders have a number.
```
