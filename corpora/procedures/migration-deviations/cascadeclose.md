# Deviation: cascadeclose.meri

- Original: `cascade_close/SKILL.md`
- Ported: `cascadeclose.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 25 -> 28 (+3 / -0)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections inert total: 0/2 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=14

## Unified diff

```diff
--- original-skills/cascade_close/SKILL.md
+++ skills/cascadeclose.meri
@@ -20,6 +20,9 @@
 Emit: "orphaned audit rows recorded for deterministic close".
 
 ## DBA notes
+
+### DBA notes — steps (( role: reference ))
+
 The source system owns physical cascade delete; Meridian records the deterministic
 audit close and refuses to invent a hidden datastore.
 
```
