# Deviation: incrementalsync.meri

- Original: `incremental_sync/SKILL.md`
- Ported: `incrementalsync.meri`
- Tier: 2 (light edits)
- Similarity: 72%
- Lines: 47 -> 53 (+17 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L31 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 33 non-blank ported lines
- Sections inert total: 3/5 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=3, structure=0, desugar=0, meaning=31

### Inert section details
- L16 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L31 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/incremental_sync/SKILL.md
+++ skills/incrementalsync.meri
@@ -9,28 +9,34 @@
 
 # Incremental Sync
 
-A watermark-based sync that runs once and moves on can leave a dataset just
-short of current if the extraction only pulls part of the backlog. This
-skill keeps retrying the extraction until the watermark actually reports
-fresh, and it treats a dataset flagged stale as out of scope for this pass
-entirely — syncing a stale dataset's watermark forward would make it look
-current without making its data trustworthy again.
+> A watermark-based sync that runs once and moves on can leave a dataset just
+> short of current if the extraction only pulls part of the backlog. This
+> skill keeps retrying the extraction until the watermark actually reports
+> fresh, and it treats a dataset flagged stale as out of scope for this pass
+> entirely — syncing a stale dataset's watermark forward would make it look
+> current without making its data trustworthy again.
 
 ## When to invoke
 - "run incremental sync"
 - "sync dataset watermarks"
 - "run the watermark sync pass"
 
-## Workflow
+## Workflow (( role: reference ))
+  until it is not the case that the watermark is fresh,
+    extract a dataset from the object store source unless the dataset is stale.
+
+### Workflow — steps
+
 fetch datasets.
 Check: any datasets.
 for each dataset:
   read the watermark for the dataset.
-  until it is not the case that the watermark is fresh,
-    extract a dataset from the object store source unless the dataset is stale.
+
+### Workflow — steps 2
+
 Emit: "incremental sync pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't call a single extraction "synced." The retry loop exists because
   one extraction call rarely closes the whole gap between the last
   watermark and the current one.
@@ -41,7 +47,7 @@
 ## Guarantees
 make sure no datasets whose status is "stale".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt confirms each dataset's watermark is fresh at the end of the
 pass, or names which ones were skipped because they were flagged stale.
 
```
