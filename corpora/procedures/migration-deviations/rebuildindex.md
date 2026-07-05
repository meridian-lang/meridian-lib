# Deviation: rebuildindex.meri

- Original: `rebuild_index/SKILL.md`
- Ported: `rebuildindex.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 24 -> 30 (+8 / -2)

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

### Inert section details
- L8 `Procedure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/rebuild_index/SKILL.md
+++ skills/rebuildindex.meri
@@ -12,9 +12,15 @@
 - "rebuild lagging indexes"
 - "index job stale"
 
-## Procedure
+## Procedure (( role: reference ))
+Check: any lagging index jobs.
+
+### Procedure — steps
+
 fetch lagging index jobs.
-Check: any lagging index jobs.
+
+### Procedure — steps 2
+
 for each index job:
   rebuild the index job.
 Emit: "lagging index jobs rebuilt".
```
