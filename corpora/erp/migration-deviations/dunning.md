# Deviation: dunning.meri

- Original: `dunning/SKILL.md`
- Ported: `dunning.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 25 -> 31 (+9 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L22 `Controls`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 2/3 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L22 `Controls`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/dunning/SKILL.md
+++ skills/dunning.meri
@@ -12,14 +12,20 @@
 - "run dunning"
 - "collect overdue invoices"
 
-## Workflow
+## Workflow (( role: reference ))
+Check: any unpaid invoices.
+
+### Workflow — steps
+
 Step: `ofbiz accounting dunning --dry-run --json` to snapshot overdue accounts.
 fetch unpaid invoices.
-Check: any unpaid invoices.
+
+### Workflow — steps 2
+
 for each invoice:
   collect payment for the invoice.
 Publish: "dunning collection pass complete".
 
-## Controls
+## Controls (( role: reference ))
 Do not contact customers whose account is under manual review.
 
```
