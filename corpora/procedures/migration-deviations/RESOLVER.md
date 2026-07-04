# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 2 (light edits)
- Similarity: 57%
- Lines: 22 -> 27 (+13 / -8)

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
+name: procedures resolver
+description: Route a synthetic DBA request to a procedure skill id.
+parameters: trigger phrase
+vocabulary: procedures.merconfig
+rulebook: procedures.merrules
+---
+
 # Procedures Resolver
 
-Routes a DBA request to the deterministic stored-procedure skill that owns it.
-
-## Dispatch table
-
+## Tables
 | trigger phrase | skill |
 | --- | --- |
 | reconcile ledger | reconcileledger |
@@ -15,8 +20,8 @@
 | purge expired records | purgeexpired |
 | settle ready batches | settlebatch |
 
-## Workflow
+## Procedure
+bind selected skill = the skill corresponding to the trigger phrase trigger phrase in the table.
+emit procedure.dispatch with skill = selected skill.
+complete.
 
-Look up the skill corresponding to the trigger phrase and emit the selected
-skill id.
-
```
