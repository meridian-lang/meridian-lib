# Deviation: pipelinetriage.meri

- Original: `pipeline_triage/SKILL.md`
- Ported: `pipelinetriage.meri`
- Tier: 2 (light edits)
- Similarity: 76%
- Lines: 58 -> 61 (+16 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L41 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 41 non-blank ported lines
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=5, structure=0, desugar=0, meaning=38

### Inert section details
- L41 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/pipeline_triage/SKILL.md
+++ skills/pipelinetriage.meri
@@ -9,14 +9,14 @@
 
 # Pipeline Triage
 
-Not every pipeline failure deserves the same response. A run that failed
-because a downstream API had a five-second blip is a different problem than
-a run that failed because an upstream schema changed underneath it, and
-treating them the same — replay everything, or escalate everything — wastes
-either compute or attention. This skill fetches the failed runs, applies a
-fast discretion table for the clear-cut cases, and for the ones that aren't
-clear-cut, splits the remaining runs into a replay lane and a judgment lane
-based on whether the failure looks transient.
+> Not every pipeline failure deserves the same response. A run that failed
+> because a downstream API had a five-second blip is a different problem than
+> a run that failed because an upstream schema changed underneath it, and
+> treating them the same — replay everything, or escalate everything — wastes
+> either compute or attention. This skill fetches the failed runs, applies a
+> fast discretion table for the clear-cut cases, and for the ones that aren't
+> clear-cut, splits the remaining runs into a replay lane and a judgment lane
+> based on whether the failure looks transient.
 
 ## When to invoke
 - "triage failed pipelines"
@@ -27,12 +27,15 @@
 fetch failed pipeline runs.
 
 !!! table (( ai-discretion ))
-| Condition                              | Action                          |
+| Condition               | Action             |
 | ----------------------------------------- | ---------------------------------- |
-| the pipeline run's status is "failed"      | escalate to the platform team    |
-| *                                         | monitor the pipeline run         |
+| the pipeline run's status is "failed"   | escalate to the platform team  |
+| *                     | monitor the pipeline run     |
 
 ## Replay Routing
+
+### Replay Routing — steps
+
 for each pipeline run:
   bind should replay = decide whether the pipeline run's failure looks transient.
   if the should replay is true,
@@ -43,7 +46,7 @@
 ## Completion
 Emit: "pipeline triage pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't replay a run just because replaying is cheap. A failure that isn't
   transient will fail the same way again, and now it's failed twice
   instead of once with a clear signal.
@@ -51,7 +54,7 @@
   judgment call is there to weigh a targeted replay against a backfill,
   not to default to the expensive option.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt separates replayed pipeline runs from ones routed to judgment,
 so a platform engineer can see the split at a glance instead of reading
 every run's individual outcome.
```
