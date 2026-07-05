# Deviation: placeorder.meri

- Original: `place_order/SKILL.md`
- Ported: `placeorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 37 -> 37 (+3 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Operator notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L24 `Checks`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L27 `Output`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/5 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Operator notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L24 `Checks`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L27 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/place_order/SKILL.md
+++ skills/placeorder.meri
@@ -12,7 +12,7 @@
 - "process open orders"
 - "place customer orders"
 
-## Operator notes
+## Operator notes (( role: reference ))
 The source system is an OFBiz-like ERP. Operators think in queues, invoices, and
 shipments rather than compiler primitives.
 
@@ -28,10 +28,10 @@
   ship the order.
 Publish: "open order queue processed".
 
-## Checks
+## Checks (( role: reference ))
 No blocked order may pass reservation or shipment release.
 
-## Output
+## Output (( role: template ))
 The operator expects a queue receipt with processed order numbers and shipment
 references.
 
```
