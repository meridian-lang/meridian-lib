# Deviation: reconcileledger.meri

- Original: `reconcile_ledger/SKILL.md`
- Ported: `reconcileledger.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 32 -> 33 (+4 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L9 `DBA notes`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L24 `Output`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 1 blocks, 0 lines

### Inert section details
- L9 `DBA notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L24 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/reconcile_ledger/SKILL.md
+++ skills/reconcileledger.meri
@@ -8,11 +8,12 @@
 
 # Reconcile Ledger
 
-## Invocation
+## Invocation (( role: procedure ))
+use judgment to follow the Invocation guidance:
 - "reconcile ledger"
 - "settle ledger batches"
 
-## DBA notes
+## DBA notes (( inert ))
 The operator starts from a SQL snapshot and then lets Meridian drive only the
 declared deterministic settlement tools.
 
@@ -27,6 +28,6 @@
 ## Assertions
 no batches whose status is "failed".
 
-## Output
+## Output (( inert, role: template ))
 The DBA expects a short reconciliation receipt and a list of settled batch ids.
 
```
