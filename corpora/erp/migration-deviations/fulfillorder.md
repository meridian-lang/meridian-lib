# Deviation: fulfillorder.meri

- Original: `fulfill_order/SKILL.md`
- Ported: `fulfillorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 31 -> 33 (+5 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L9 `Operator notes`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L9 `Operator notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/fulfill_order/SKILL.md
+++ skills/fulfillorder.meri
@@ -8,11 +8,12 @@
 
 # Fulfill Order
 
-## When this applies
+## When this applies (( role: procedure ))
+use judgment to follow the When this applies guidance:
 - "fulfill ERP orders"
 - "release shipments"
 
-## Operator notes
+## Operator notes (( inert ))
 Warehouse operators say "release the shipment" rather than "invoke the
 fulfillment workflow." This skill keeps that vocabulary while compiling to
 declared tool calls.
@@ -26,6 +27,7 @@
   ship the order.
 Publish: "shipment release queue drained".
 
-## Checks
+## Checks (( role: procedure ))
+use judgment to follow the Checks guidance:
 Every released order should already have inventory reserved.
 
```
