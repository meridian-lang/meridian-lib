# Deviation: rebuildindex.meri

- Original: `rebuild_index/SKILL.md`
- Ported: `rebuildindex.meri`
- Tier: 2 (light edits)
- Similarity: 74%
- Lines: 24 -> 33 (+12 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections inert total: 0/3 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Judgment: 3 blocks, 0 lines

## Unified diff

```diff
--- original-skills/rebuild_index/SKILL.md
+++ skills/rebuildindex.meri
@@ -8,17 +8,26 @@
 
 # Rebuild Index
 
-## Use this when
+## Use this when (( role: procedure ))
+use judgment to follow the Use this when guidance:
 - "rebuild lagging indexes"
 - "index job stale"
 
 ## Procedure
+use judgment to follow the Procedure guidance:
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
 
-## Assertions
+## Assertions (( role: procedure ))
+use judgment to follow the Assertions guidance:
 make sure all index jobs have a name.
 
```
