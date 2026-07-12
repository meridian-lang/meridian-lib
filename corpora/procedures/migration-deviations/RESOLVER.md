# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 27 -> 30 (+5 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L26 `Workflow`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 22 non-blank ported lines
- Sections inert total: 1/1 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=22

### Inert section details
- L26 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/RESOLVER.md
+++ RESOLVER.meri
@@ -1,8 +1,11 @@
 # Procedures Resolver
 
-Routes a DBA request to the deterministic stored-procedure skill that owns it.
+> Routes a DBA request to the deterministic stored-procedure skill that owns it.
 
 ## Dispatch table
+
+
+### Dispatch table — steps (( role: reference ))
 
 | trigger phrase | skill |
 | --- | --- |
@@ -20,7 +23,7 @@
 | checksum audit | checksumaudit |
 | check ledger parity | ledgerparitywatch |
 
-## Workflow
+## Workflow (( role: reference ))
 
 Look up the skill corresponding to the trigger phrase and emit the selected
 skill id.
```
