# Deviation: monthendclose.meri

- Original: `month_end_close/SKILL.md`
- Ported: `monthendclose.meri`
- Tier: 1 (near-verbatim)
- Similarity: 96%
- Lines: 26 -> 26 (+1 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L16 `Accounting notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=14

### Inert section details
- L16 `Accounting notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/month_end_close/SKILL.md
+++ skills/monthendclose.meri
@@ -20,7 +20,7 @@
 close the accounting period.
 Publish: "accounting period closed".
 
-## Accounting notes
+## Accounting notes (( role: reference ))
 The real-world phrase "soft close" is intentionally left as documentation; the
 compiled behavior uses an explicit period-close tool.
 
```
