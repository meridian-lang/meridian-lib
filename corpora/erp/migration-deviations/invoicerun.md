# Deviation: invoicerun.meri

- Original: `invoice_run/SKILL.md`
- Ported: `invoicerun.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 39 -> 45 (+12 / -6)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L36 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 28 non-blank ported lines
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=29

### Inert section details
- L14 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L36 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/invoice_run/SKILL.md
+++ skills/invoicerun.meri
@@ -18,11 +18,7 @@
 | unpaid | collections |
 | fulfilled | archive |
 
-## Workflow
-fetch open orders.
-for each order:
-  create an invoice for the order.
-bind selected queue = the queue corresponding to the status "unpaid" in the table.
+## Workflow (( role: reference ))
 let high value count be the number of high value orders.
 bind invoice receipt =
   ```
@@ -32,8 +28,18 @@
   selected: {{ selected queue }}
   high value orders: {{ high value count }}
   ```
+
+### Workflow — steps
+
+fetch open orders.
+for each order:
+  create an invoice for the order.
+bind selected queue = the queue corresponding to the status "unpaid" in the table.
+
+### Workflow — steps 2
+
 emit erp.invoice_receipt with body = invoice receipt.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt groups invoice states by downstream queue and reports the high-value order count.
 
```
