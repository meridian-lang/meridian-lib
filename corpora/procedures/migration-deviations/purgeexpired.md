# Deviation: purgeexpired.meri

- Original: `purge_expired/SKILL.md`
- Ported: `purgeexpired.meri`
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
- L21 `Operator notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 16 non-blank ported lines
- Sections inert total: 1/2 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=15

### Inert section details
- L21 `Operator notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/purge_expired/SKILL.md
+++ skills/purgeexpired.meri
@@ -13,6 +13,9 @@
 - "retention cleanup"
 
 ## Procedure
+
+### Procedure — steps
+
 fetch stale records.
 Check: any stale records.
 Check: at most 500 stale records.
@@ -22,6 +25,6 @@
   Emit: "expired record purge failed".
 Emit: "expired records purged".
 
-## Operator notes
+## Operator notes (( role: reference ))
 The limit of 100 mirrors a stored procedure batch size and keeps replay bounded.
 
```
