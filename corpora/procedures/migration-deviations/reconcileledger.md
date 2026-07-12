# Deviation: reconcileledger.meri

- Original: `reconcile_ledger/SKILL.md`
- Ported: `reconcileledger.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 36 -> 39 (+4 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `DBA notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 24 non-blank ported lines
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=7, structure=0, desugar=0, meaning=22

### Inert section details
- L8 `DBA notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/reconcile_ledger/SKILL.md
+++ skills/reconcileledger.meri
@@ -12,11 +12,14 @@
 - "reconcile ledger"
 - "settle ledger batches"
 
-## DBA notes
+## DBA notes (( role: reference ))
 The operator starts from a SQL snapshot and then lets Meridian drive only the
 declared deterministic settlement tools.
 
 ## Procedure
+
+### Procedure — steps
+
 SQL: `psql -c "select id,status from ledger_batch where status='ready'" --csv` to snapshot ready batches.
 fetch ready batches.
 Check: all batches have a name.
```
