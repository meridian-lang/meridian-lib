# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 2 (light edits)
- Similarity: 61%
- Lines: 22 -> 27 (+12 / -7)

## Frontmatter
- Added: `description`, `name`, `parameters`, `rulebook`, `vocabulary`
- Removed: (none)

## Categories
- frontmatter-injected

## Metrics
- Sections: 0/2 inert (0% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/RESOLVER.md
+++ RESOLVER.meri
@@ -1,9 +1,14 @@
+---
+name: erp resolver
+description: Route a synthetic ERP operator request to a skill id.
+parameters: trigger phrase
+vocabulary: erp.merconfig
+rulebook: erp.merrules
+---
+
 # ERP Resolver
 
-Routes an ERP operator request to the synthetic ERP skill that owns it.
-
-## Dispatch table
-
+## Tables
 | trigger phrase | skill |
 | --- | --- |
 | process open orders | placeorder |
@@ -16,7 +21,7 @@
 | month-end close | monthendclose |
 
 ## Workflow
+bind selected skill = the skill corresponding to the trigger phrase trigger phrase in the table.
+emit erp.dispatch with skill = selected skill.
+complete.
 
-Look up the skill corresponding to the trigger phrase and emit the selected
-skill id.
-
```
