# Deviation: purgeexpired.meri

- Original: `purge_expired/SKILL.md`
- Ported: `purgeexpired.meri`
- Tier: 2 (light edits)
- Similarity: 73%
- Lines: 26 -> 34 (+12 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L25 `Operator notes`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L25 `Operator notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/purge_expired/SKILL.md
+++ skills/purgeexpired.meri
@@ -8,19 +8,27 @@
 
 # Purge Expired
 
-## Use this when
+## Use this when (( role: procedure ))
+use judgment to follow the Use this when guidance:
 - "purge expired records"
 - "retention cleanup"
 
 ## Procedure
+use judgment to follow the Procedure guidance:
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
+## Operator notes (( inert ))
 The limit of 100 mirrors a stored procedure batch size and keeps replay bounded.
 
```
