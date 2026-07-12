# Deviation: placeorder.meri

- Original: `place_order/SKILL.md`
- Ported: `placeorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 45 -> 48 (+6 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Operator notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Checks`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Output`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 32 non-blank ported lines
- Sections inert total: 3/4 (75% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=8, structure=0, desugar=0, meaning=29

### Inert section details
- L8 `Operator notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Checks`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/place_order/SKILL.md
+++ skills/placeorder.meri
@@ -12,11 +12,14 @@
 - "process open orders"
 - "place customer orders"
 
-## Operator notes
+## Operator notes (( role: reference ))
 The source system is an OFBiz-like ERP. Operators think in queues, invoices, and
 shipments rather than compiler primitives.
 
 ## Workflow
+
+### Workflow — steps
+
 Step: `ofbiz order-check --queue open --json` to snapshot the open order queue.
 fetch open orders.
 Check: all orders have a number.
@@ -36,10 +39,10 @@
   ship the order.
 Publish: "open order queue processed".
 
-## Checks
+## Checks (( role: reference ))
 No blocked order may pass reservation or shipment release.
 
-## Output
+## Output (( role: template ))
 The operator expects a queue receipt with processed order numbers and shipment
 references, plus the top 3 orders by total amount.
 
```
