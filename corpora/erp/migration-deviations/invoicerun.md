# Deviation: invoicerun.meri

- Original: `invoice_run/SKILL.md`
- Ported: `invoicerun.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 37 -> 43 (+12 / -6)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L34 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L14 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
 bind invoice receipt =
   ```
   invoice-routing:
@@ -30,8 +26,18 @@
   [end for]
   selected: {{ selected queue }}
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
 The receipt groups invoice states by downstream queue.
 
```
