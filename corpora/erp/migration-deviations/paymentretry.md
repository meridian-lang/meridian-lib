# Deviation: paymentretry.meri

- Original: `payment_retry/SKILL.md`
- Ported: `paymentretry.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 27 -> 33 (+9 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L24 `Controls`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 17 non-blank ported lines
- Sections inert total: 2/3 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=16

### Inert section details
- L8 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L24 `Controls`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/payment_retry/SKILL.md
+++ skills/paymentretry.meri
@@ -12,16 +12,22 @@
 - "retry declined payments"
 - "reattempt invoice collection"
 
-## Workflow
+## Workflow (( role: reference ))
+  until it is not the case that the invoice is unpaid,
+
+### Workflow — steps
+
 1. fetch unpaid invoices.
 2. Check: any unpaid invoices.
 3. for each invoice:
-  until it is not the case that the invoice is unpaid,
+
+### Workflow — steps 2
+
     1. collect payment for the invoice.
     2. recover where the error code equals "payment.declined":
       escalate the invoice.
 4. Publish: "payment retry pass complete".
 
-## Controls
+## Controls (( role: reference ))
 Do not retry payments for a customer whose account is under manual review.
 
```
