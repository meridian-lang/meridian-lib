# Deviation: backfillpartitions.meri

- Original: `backfill_partitions/SKILL.md`
- Ported: `backfillpartitions.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 49 -> 49 (+9 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L28 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=36

### Inert section details
- L28 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/backfill_partitions/SKILL.md
+++ skills/backfillpartitions.meri
@@ -9,13 +9,13 @@
 
 # Backfill Partitions
 
-Backfilling old partitions is inherently slow — there can be a lot of them,
-and each one takes real time to reprocess. What this skill refuses to do is
-let that slowness stall the rest of the pipeline's quality cadence. It picks
-the oldest five partitions per dataset, backfills them in parallel, and
-kicks off the dataset's quality checks in the background at the same time,
-so a long backfill and an unrelated quality pass aren't competing for the
-same window.
+> Backfilling old partitions is inherently slow — there can be a lot of them,
+> and each one takes real time to reprocess. What this skill refuses to do is
+> let that slowness stall the rest of the pipeline's quality cadence. It picks
+> the oldest five partitions per dataset, backfills them in parallel, and
+> kicks off the dataset's quality checks in the background at the same time,
+> so a long backfill and an unrelated quality pass aren't competing for the
+> same window.
 
 ## When to invoke
 - "backfill dataset partitions"
@@ -33,7 +33,7 @@
     in the background, run quality checks on the dataset.
 Emit: "partition backfill pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't widen the backfill window past the oldest five partitions on a
   whim. A larger batch is a longer-running simultaneous block, which
   competes harder with whatever else the pipeline needs to do at the same
@@ -42,7 +42,7 @@
   the backfill as complete — it runs in the background precisely so it
   doesn't gate this skill's own completion.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt calls out the oldest partitions selected for backfill per
 dataset, so an engineer can confirm the right window was chosen without
 re-running the sort themselves.
```
