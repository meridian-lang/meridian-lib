# Deviation: fulfillorder.meri

- Original: `fulfill_order/SKILL.md`
- Ported: `fulfillorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 31 -> 31 (+2 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Operator notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L22 `Checks`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Operator notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L22 `Checks`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/fulfill_order/SKILL.md
+++ skills/fulfillorder.meri
@@ -12,7 +12,7 @@
 - "fulfill ERP orders"
 - "release shipments"
 
-## Operator notes
+## Operator notes (( role: reference ))
 Warehouse operators say "release the shipment" rather than "invoke the
 fulfillment workflow." This skill keeps that vocabulary while compiling to
 declared tool calls.
@@ -26,6 +26,6 @@
   ship the order.
 Publish: "shipment release queue drained".
 
-## Checks
+## Checks (( role: reference ))
 Every released order should already have inventory reserved.
 
```
