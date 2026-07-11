# Deviation: dunning.meri

- Original: `dunning/SKILL.md`
- Ported: `dunning.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 27 -> 30 (+4 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L21 `Controls`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 1/2 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=18

### Inert section details
- L21 `Controls`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/dunning/SKILL.md
+++ skills/dunning.meri
@@ -13,6 +13,9 @@
 - "collect overdue invoices"
 
 ## Workflow
+
+### Workflow — steps
+
 Step: `ofbiz accounting dunning --dry-run --json` to snapshot overdue accounts.
 fetch unpaid invoices.
 Check: any unpaid invoices.
@@ -22,6 +25,6 @@
     escalate the invoice.
 Publish: "dunning collection pass complete".
 
-## Controls
+## Controls (( role: reference ))
 Do not contact customers whose account is under manual review.
 
```
