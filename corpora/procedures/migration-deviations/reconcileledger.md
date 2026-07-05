# Deviation: reconcileledger.meri

- Original: `reconcile_ledger/SKILL.md`
- Ported: `reconcileledger.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 32 -> 32 (+2 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `DBA notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Output`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `DBA notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/reconcile_ledger/SKILL.md
+++ skills/reconcileledger.meri
@@ -12,7 +12,7 @@
 - "reconcile ledger"
 - "settle ledger batches"
 
-## DBA notes
+## DBA notes (( role: reference ))
 The operator starts from a SQL snapshot and then lets Meridian drive only the
 declared deterministic settlement tools.
 
@@ -27,6 +27,6 @@
 ## Assertions
 no batches whose status is "failed".
 
-## Output
+## Output (( role: template ))
 The DBA expects a short reconciliation receipt and a list of settled batch ids.
 
```
