# Deviation: schemaevolution.meri

- Original: `schema_evolution/SKILL.md`
- Ported: `schemaevolution.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 49 -> 52 (+12 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L30 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L30 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/schema_evolution/SKILL.md
+++ skills/schemaevolution.meri
@@ -9,13 +9,13 @@
 
 # Schema Evolution
 
-An upstream producer renaming or retyping a column is invisible until it
-breaks a downstream query — usually the query, not the load, because a
-naive extract-load path will happily load an incompatible schema and let
-the incompatibility surface three steps later. This skill puts the
-compatibility check where it belongs: before the load, not after. A
-compatible schema loads immediately; an incompatible one gets held, with a
-note explaining why, rather than silently landing in the warehouse.
+> An upstream producer renaming or retyping a column is invisible until it
+> breaks a downstream query — usually the query, not the load, because a
+> naive extract-load path will happily load an incompatible schema and let
+> the incompatibility surface three steps later. This skill puts the
+> compatibility check where it belongs: before the load, not after. A
+> compatible schema loads immediately; an incompatible one gets held, with a
+> note explaining why, rather than silently landing in the warehouse.
 
 ## When to invoke
 - "check schema evolution"
@@ -23,6 +23,9 @@
 - "run schema compatibility check"
 
 ## Workflow
+
+### Workflow — steps
+
 fetch datasets.
 for each dataset:
   validate the schema for the dataset.
@@ -32,7 +35,7 @@
     Note: "schema incompatible, dataset held for manual review".
 Emit: "schema evolution pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't load an incompatible schema "just this once" to unblock a
   downstream consumer. That's exactly the load that breaks the consumer's
   query the next time it runs.
@@ -43,7 +46,7 @@
 ## Guarantees
 make sure no datasets whose status is "stale".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states which datasets loaded cleanly and which were held for
 manual review because of an incompatible schema.
 
```
