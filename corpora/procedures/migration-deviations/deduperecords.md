# Deviation: deduperecords.meri

- Original: `dedupe_records/SKILL.md`
- Ported: `deduperecords.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 29 -> 32 (+3 / -0)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- (none)

## Metrics
- generated_loc: 18 non-blank ported lines
- Sections inert total: 0/2 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=6, structure=0, desugar=0, meaning=16

## Unified diff

```diff
--- original-skills/dedupe_records/SKILL.md
+++ skills/deduperecords.meri
@@ -13,6 +13,9 @@
 - "duplicate rows detected"
 
 ## Procedure
+
+### Procedure — steps
+
 fetch duplicate records.
 Check: any duplicate records.
 for each record whose status is "duplicate":
```
