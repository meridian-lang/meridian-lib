# Deviation: dedupeupsert.meri

- Original: `dedupe_upsert/SKILL.md`
- Ported: `dedupeupsert.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 50 -> 53 (+12 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L32 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=6, structure=0, desugar=0, meaning=31

### Inert section details
- L32 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/dedupe_upsert/SKILL.md
+++ skills/dedupeupsert.meri
@@ -9,13 +9,13 @@
 
 # Dedupe Upsert
 
-Duplicate and stale datasets accumulate in any pipeline that retries on
-failure or re-ingests from an upstream that occasionally double-sends. This
-skill doesn't treat that as an emergency — it treats it as routine
-maintenance, bounded by how many duplicates are tolerable before something
-upstream needs a harder look. Within that band, it dedupes records in place;
-outside a tolerable state, it leaves a dataset's blocked status alone rather
-than forcing a merge that isn't safe yet.
+> Duplicate and stale datasets accumulate in any pipeline that retries on
+> failure or re-ingests from an upstream that occasionally double-sends. This
+> skill doesn't treat that as an emergency — it treats it as routine
+> maintenance, bounded by how many duplicates are tolerable before something
+> upstream needs a harder look. Within that band, it dedupes records in place;
+> outside a tolerable state, it leaves a dataset's blocked status alone rather
+> than forcing a merge that isn't safe yet.
 
 ## When to invoke
 - "dedupe datasets"
@@ -23,6 +23,9 @@
 - "collapse duplicate datasets"
 
 ## Workflow
+
+### Workflow — steps
+
 fetch datasets.
 Check: at most 5 datasets whose status is "duplicate".
 Check: at least 0 datasets whose status is "stale".
@@ -34,7 +37,7 @@
     make sure the dataset's status is not "is-blocked".
 Emit: "dedupe upsert pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't force a dedupe on a dataset that's flagged `is-blocked`. That flag
   means something upstream needs attention first; deduping through it
   papers over the real problem.
@@ -44,7 +47,7 @@
 ## Assertions
 confirm at most 5 datasets whose status is "duplicate".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states how many datasets were deduped this pass and confirms
 there is exactly one canonical dataset left standing.
 
```
