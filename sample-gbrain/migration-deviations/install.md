# Deviation: install.meri

- Original: `install/SKILL.md`
- Ported: `install.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 10 -> 12 (+2 / -0)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L3 `Overview`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 8 non-blank ported lines
- Sections inert total: 1/1 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=8

### Inert section details
- L3 `Overview`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/install/SKILL.md
+++ skills/install.meri
@@ -1,4 +1,6 @@
 # Install GBrain (Deprecated)
+
+## Overview (( role: reference ))
 
 This skill has been replaced by the **setup** skill. See `skills/setup/SKILL.md`.
 
```
