# Deviation: cascadeclose.meri

- Original: `cascade_close/SKILL.md`
- Ported: `cascadeclose.meri`
- Tier: 1 (near-verbatim)
- Similarity: 96%
- Lines: 25 -> 25 (+1 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L15 `DBA notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 13 non-blank ported lines
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=11

### Inert section details
- L15 `DBA notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/cascade_close/SKILL.md
+++ skills/cascadeclose.meri
@@ -19,7 +19,7 @@
 Check: at most 200 orphaned audit rows.
 Emit: "orphaned audit rows recorded for deterministic close".
 
-## DBA notes
+## DBA notes (( role: reference ))
 The source system owns physical cascade delete; Meridian records the deterministic
 audit close and refuses to invent a hidden datastore.
 
```
