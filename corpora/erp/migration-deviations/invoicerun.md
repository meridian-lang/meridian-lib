# Deviation: invoicerun.meri

- Original: `invoice_run/SKILL.md`
- Ported: `invoicerun.meri`
- Tier: 2 (light edits)
- Similarity: 76%
- Lines: 37 -> 45 (+14 / -6)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L36 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L36 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/invoice_run/SKILL.md
+++ skills/invoicerun.meri
@@ -8,7 +8,8 @@
 
 # Invoice Run
 
-## When this applies
+## When this applies (( role: procedure ))
+use judgment to follow the When this applies guidance:
 - "run invoices"
 - "billing batch"
 
@@ -19,10 +20,7 @@
 | fulfilled | archive |
 
 ## Workflow
-fetch open orders.
-for each order:
-  create an invoice for the order.
-bind selected queue = the queue corresponding to the status "unpaid" in the table.
+use judgment to follow the Workflow guidance:
 bind invoice receipt =
   ```
   invoice-routing:
@@ -30,8 +28,18 @@
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
+## Report shape (( inert, role: template ))
 The receipt groups invoice states by downstream queue.
 
```
