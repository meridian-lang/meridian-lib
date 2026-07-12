# Deviation: RESOLVER.meri

- Original: `RESOLVER.md`
- Ported: `RESOLVER.meri`
- Tier: 2 (light edits)
- Similarity: 85%
- Lines: 23 -> 29 (+7 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- generated_loc: 19 non-blank ported lines
- Sections inert total: 0/0 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=19

## Unified diff

```diff
--- original-skills/RESOLVER.md
+++ RESOLVER.meri
@@ -1,8 +1,11 @@
 # Incident Resolver
 
-Routes an SRE on-call request to the synthetic incident skill that owns it.
+> Routes an SRE on-call request to the synthetic incident skill that owns it.
 
 ## Dispatch table
+
+
+### Dispatch table — steps (( role: reference ))
 
 | trigger phrase | skill |
 | --- | --- |
@@ -18,6 +21,9 @@
 
 ## Workflow
 
+
+### Workflow — steps (( role: reference ))
+
 Look up the skill corresponding to the trigger phrase and emit the selected
 skill id.
 
```
