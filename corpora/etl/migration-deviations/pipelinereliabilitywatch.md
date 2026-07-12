# Deviation: pipelinereliabilitywatch.meri

- Original: `pipeline_reliability_watch/SKILL.md`
- Ported: `pipelinereliabilitywatch.meri`
- Tier: 2 (light edits)
- Similarity: 66%
- Lines: 61 -> 76 (+31 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L44 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L64 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 49 non-blank ported lines
- Sections inert total: 4/6 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=10, structure=0, desugar=0, meaning=42

### Inert section details
- L20 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L52 `Guarantees`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L64 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/pipeline_reliability_watch/SKILL.md
+++ skills/pipelinereliabilitywatch.meri
@@ -9,12 +9,12 @@
 
 # Pipeline Reliability Watch
 
-An ETL pipeline can look calm right up until the day the quiet failures stop
-being rare and start being normal. The operator usually needs two different
-views of that drift: whether whole runs are landing cleanly, and whether the
-individual failure occurrences inside those runs are staying below a safe
-background rate. This skill keeps both views visible and says "unknown" out
-loud when the retained sample is still too small to support either claim.
+> An ETL pipeline can look calm right up until the day the quiet failures stop
+> being rare and start being normal. The operator usually needs two different
+> views of that drift: whether whole runs are landing cleanly, and whether the
+> individual failure occurrences inside those runs are staying below a safe
+> background rate. This skill keeps both views visible and says "unknown" out
+> loud when the retained sample is still too small to support either claim.
 
 ## Contract
 1. the extract step usually succeeds, checked every 1 days.
@@ -25,22 +25,31 @@
 - "check pipeline reliability"
 - "monitor extract load reliability"
 
-## Workflow
+## Workflow (( role: reference ))
+3. otherwise,
+  Emit: "pipeline reliability saw unhealthy run frequency".
+6. otherwise,
+  Emit: "pipeline reliability saw unhealthy occurrence frequency".
+
+### Workflow — steps
+
 1. if the extract step succeeds in at least 90% of runs within the last 30 days,
   Emit: "pipeline reliability saw healthy run frequency".
 2. if it is unknown whether:
   Emit: "pipeline reliability run frequency is indeterminate below the sample floor".
-3. otherwise,
-  Emit: "pipeline reliability saw unhealthy run frequency".
+
+### Workflow — steps 2
+
 4. if the load step fails in at most 5% of occurrences within the last 30 days,
   Emit: "pipeline reliability saw healthy occurrence frequency".
 5. if it is unknown whether:
   Emit: "pipeline reliability occurrence frequency is indeterminate below the sample floor".
-6. otherwise,
-  Emit: "pipeline reliability saw unhealthy occurrence frequency".
+
+### Workflow — steps 3
+
 7. Emit: "pipeline reliability watch pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't use the run-frequency branch to answer an occurrence-frequency
   question. A clean run can still hide too many noisy failures inside it.
 - Don't treat an indeterminate sample-floor result as a green result. Thin
@@ -48,13 +57,19 @@
 - Don't move the cadence out of the Contract lines. The monitored claim needs
   to say when it is checked, not leave that to a side note.
 
-## Guarantees
-make sure the extract step succeeds in at least 90% of runs within the last 30 days otherwise:
+## Guarantees (( role: reference ))
   Emit: "pipeline reliability guarantee recorded a run-frequency breach".
-make sure the load step fails in at most 5% of occurrences within the last 30 days otherwise:
   Emit: "pipeline reliability guarantee recorded an occurrence-frequency breach".
 
-## Report shape
+
+### Guarantees — steps
+
+make sure the extract step succeeds in at least 90% of runs within the last 30 days otherwise:
+
+### Guarantees — steps 2
+
+make sure the load step fails in at most 5% of occurrences within the last 30 days otherwise:
+## Report shape (( role: template ))
 The receipt records one verdict for run frequency and one for occurrence
 frequency, with a separate indeterminate path when the retained sample is still
 too small to support the claim.
```
