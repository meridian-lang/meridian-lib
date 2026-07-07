# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 26 -> 29 (+5 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L25 `Workflow`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 1/1 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L25 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

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
@@ -19,7 +22,7 @@
 | retry failed batches | retryfailedbatch |
 | checksum audit | checksumaudit |
 
-## Workflow
+## Workflow (( role: reference ))
 
 Look up the skill corresponding to the trigger phrase and emit the selected
 skill id.
```
