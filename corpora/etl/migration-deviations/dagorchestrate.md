# Deviation: dagorchestrate.meri

- Original: `dag_orchestrate/SKILL.md`
- Ported: `dagorchestrate.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 48 -> 48 (+10 / -10)

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
- L36 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L28 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L36 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/dag_orchestrate/SKILL.md
+++ skills/dagorchestrate.meri
@@ -9,14 +9,14 @@
 
 # Dag Orchestrate
 
-A pipeline stage that starts as soon as its own schedule fires — without
-checking whether its upstream dependency actually finished — is a race
-condition waiting to be noticed. This skill closes that gap by waiting on
-the upstream's completion event before doing anything, and waiting on a
-readiness signal from the orchestrator on top of that as a second gate.
-Once both gates clear, the extraction and the quality check run
-simultaneously rather than sequentially, since neither one depends on the
-other's result.
+> A pipeline stage that starts as soon as its own schedule fires — without
+> checking whether its upstream dependency actually finished — is a race
+> condition waiting to be noticed. This skill closes that gap by waiting on
+> the upstream's completion event before doing anything, and waiting on a
+> readiness signal from the orchestrator on top of that as a second gate.
+> Once both gates clear, the extraction and the quality check run
+> simultaneously rather than sequentially, since neither one depends on the
+> other's result.
 
 ## When to invoke
 - "orchestrate pipeline dag"
@@ -33,7 +33,7 @@
     run quality checks on the dataset.
 Emit: "dag orchestration pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't remove the `pipeline.ready` wait to shave latency. The upstream
   completion event only proves the upstream is done; it doesn't prove the
   orchestrator has cleared this stage to start.
@@ -41,7 +41,7 @@
   They're independent once both gates clear — running them one after the
   other only adds latency without adding safety.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt confirms each dataset's upstream signal and downstream
 extraction, so a pipeline engineer can see exactly where a stage was
 waiting versus where it was actually running.
```
