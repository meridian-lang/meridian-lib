# Deviation: retryfailedbatch.meri

- Original: `retry_failed_batch/SKILL.md`
- Ported: `retryfailedbatch.meri`
- Tier: 2 (light edits)
- Similarity: 72%
- Lines: 29 -> 38 (+14 / -5)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- generated_loc: 20 non-blank ported lines
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=18

### Inert section details
- L8 `Procedure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/retry_failed_batch/SKILL.md
+++ skills/retryfailedbatch.meri
@@ -12,16 +12,25 @@
 - "retry failed batches"
 - "reattempt batch settlement"
 
-## Procedure
-fetch failed batches.
-Check: any batches whose status is "failed".
+## Procedure (( role: reference ))
 while any batches whose status is "failed",
   for each batch whose status is "failed":
     retry the batch unless the batch is finalized.
+  until it is not the case that the batch is ready,
+    settle the batch.
+
+### Procedure — steps
+
+fetch failed batches.
+Check: any batches whose status is "failed".
+
+### Procedure — steps 2
+
 fetch ready batches.
 for each batch:
-  until it is not the case that the batch is ready,
-    settle the batch.
+
+### Procedure — steps 3
+
 Emit: "failed batch retry pass complete".
 
 ## Postconditions
```
