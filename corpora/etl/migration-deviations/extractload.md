# Deviation: extractload.meri

- Original: `extract_load/SKILL.md`
- Ported: `extractload.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 48 -> 55 (+15 / -8)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L44 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 35 non-blank ported lines
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=34

### Inert section details
- L29 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/extract_load/SKILL.md
+++ skills/extractload.meri
@@ -9,12 +9,12 @@
 
 # Extract Load
 
-Most of what goes wrong in a data pipeline isn't the extraction — it's
-loading a dataset whose schema silently drifted, or losing track of a load
-that failed halfway. This skill keeps the ordinary path boring: fetch the
-datasets that are due, validate each one's schema before touching the
-warehouse, load it, and if the load itself fails, hold the dataset for
-replay instead of leaving it in an ambiguous half-loaded state.
+> Most of what goes wrong in a data pipeline isn't the extraction — it's
+> loading a dataset whose schema silently drifted, or losing track of a load
+> that failed halfway. This skill keeps the ordinary path boring: fetch the
+> datasets that are due, validate each one's schema before touching the
+> warehouse, load it, and if the load itself fails, hold the dataset for
+> replay instead of leaving it in an ambiguous half-loaded state.
 
 ## When to invoke
 - "run extract load"
@@ -22,6 +22,9 @@
 - "run the extract-load pass"
 
 ## Workflow
+
+### Workflow — steps
+
 fetch datasets.
 Check: all datasets have a name.
 extract a dataset from the object store source.
@@ -31,10 +34,14 @@
   Note: "load failed, dataset held for replay".
 Emit: "extract load pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't load a dataset before its schema has been validated, even when the
   source is "usually fine." The validation step exists precisely for the
   runs where it isn't.
+
+### Anti-Patterns — steps
+
+use judgment to follow the Anti-Patterns — steps guidance:
 - Don't retry a failed load inline in a tight loop. Hold it for replay —
   `pipeline triage` is the skill that decides whether a failure is worth
   replaying at all.
@@ -42,7 +49,7 @@
 ## Guarantees
 make sure all datasets have a name.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt confirms the load outcome per dataset, and names anything held
 for replay after a failed load call.
 
```
