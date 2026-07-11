# Deviation: settlebatch.meri

- Original: `settle_batch/SKILL.md`
- Ported: `settlebatch.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 27 -> 33 (+10 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=17

### Inert section details
- L8 `Batch body`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/settle_batch/SKILL.md
+++ skills/settlebatch.meri
@@ -12,14 +12,20 @@
 - "settle ready batches"
 - "batch settlement"
 
-## Batch body
+## Batch body (( role: reference ))
+  recover from any:
+    until it is not the case that the batch is ready,
+      retry the batch.
+
+### Batch body — steps
+
 fetch ready batches.
 Check: all batches have a name.
 for each batch:
   settle the batch unless the batch is finalized.
-  recover from any:
-    until it is not the case that the batch is ready,
-      retry the batch.
+
+### Batch body — steps 2
+
 Emit: "ready batches settled".
 
 ## Postconditions
```
