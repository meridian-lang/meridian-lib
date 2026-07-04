# Deviation: placeorder.meri

- Original: `place_order/SKILL.md`
- Ported: `placeorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 37 -> 39 (+6 / -4)

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
- L29 `Output`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L9 `Operator notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L29 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/place_order/SKILL.md
+++ skills/placeorder.meri
@@ -8,11 +8,12 @@
 
 # Place Order
 
-## When this applies
+## When this applies (( role: procedure ))
+use judgment to follow the When this applies guidance:
 - "process open orders"
 - "place customer orders"
 
-## Operator notes
+## Operator notes (( inert ))
 The source system is an OFBiz-like ERP. Operators think in queues, invoices, and
 shipments rather than compiler primitives.
 
@@ -28,10 +29,11 @@
   ship the order.
 Publish: "open order queue processed".
 
-## Checks
+## Checks (( role: procedure ))
+use judgment to follow the Checks guidance:
 No blocked order may pass reservation or shipment release.
 
-## Output
+## Output (( inert, role: template ))
 The operator expects a queue receipt with processed order numbers and shipment
 references.
 
```
