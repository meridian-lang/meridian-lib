# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 22 -> 27 (+7 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections inert total: 0/1 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Judgment: 1 blocks, 0 lines

## Unified diff

```diff
--- original-skills/RESOLVER.md
+++ RESOLVER.meri
@@ -1,9 +1,13 @@
 # ERP Resolver
 
-Routes an ERP operator request to the synthetic ERP skill that owns it.
+> Routes an ERP operator request to the synthetic ERP skill that owns it.
 
-## Dispatch table
+## Dispatch table (( inert ))
 
+
+### Dispatch table — steps
+
+!!! table (( ai-discretion ))
 | trigger phrase | skill |
 | --- | --- |
 | process open orders | placeorder |
@@ -16,6 +20,7 @@
 | month-end close | monthendclose |
 
 ## Workflow
+use judgment to follow the Workflow guidance:
 
 Look up the skill corresponding to the trigger phrase and emit the selected
 skill id.
```
