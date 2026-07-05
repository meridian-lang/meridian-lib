# Deviation: purgeexpired.meri

- Original: `purge_expired/SKILL.md`
- Ported: `purgeexpired.meri`
- Tier: 2 (light edits)
- Similarity: 76%
- Lines: 26 -> 32 (+10 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L23 `Operator notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 2/3 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Procedure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Operator notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/purge_expired/SKILL.md
+++ skills/purgeexpired.meri
@@ -12,15 +12,21 @@
 - "purge expired records"
 - "retention cleanup"
 
-## Procedure
+## Procedure (( role: reference ))
+Check: any stale records.
+
+### Procedure — steps
+
 fetch stale records.
-Check: any stale records.
+
+### Procedure — steps 2
+
 for each the first 100 records whose status is "stale" sorted by updated at, oldest first:
   purge the record.
-recover from any:
+> recover from any:
   Emit: "expired record purge failed".
 Emit: "expired records purged".
 
-## Operator notes
+## Operator notes (( role: reference ))
 The limit of 100 mirrors a stored procedure batch size and keeps replay bounded.
 
```
