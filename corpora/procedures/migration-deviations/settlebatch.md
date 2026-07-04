# Deviation: settlebatch.meri

- Original: `settle_batch/SKILL.md`
- Ported: `settlebatch.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 24 -> 26 (+4 / -2)

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
- Judgment: 2 blocks, 0 lines

## Unified diff

```diff
--- original-skills/settle_batch/SKILL.md
+++ skills/settlebatch.meri
@@ -8,7 +8,8 @@
 
 # Settle Batch
 
-## Invocation
+## Invocation (( role: procedure ))
+use judgment to follow the Invocation guidance:
 - "settle ready batches"
 - "batch settlement"
 
@@ -19,6 +20,7 @@
   settle the batch.
 Emit: "ready batches settled".
 
-## Postconditions
+## Postconditions (( role: procedure ))
+use judgment to follow the Postconditions guidance:
 make sure no batches whose status is "failed".
 
```
