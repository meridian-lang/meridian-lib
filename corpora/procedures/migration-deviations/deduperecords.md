# Deviation: deduperecords.meri

- Original: `dedupe_records/SKILL.md`
- Ported: `deduperecords.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 25 -> 31 (+8 / -2)

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
--- original-skills/dedupe_records/SKILL.md
+++ skills/deduperecords.meri
@@ -12,9 +12,15 @@
 - "dedupe records"
 - "duplicate rows detected"
 
-## Procedure
+## Procedure (( role: reference ))
+Check: any duplicate records.
+
+### Procedure — steps
+
 fetch duplicate records.
-Check: any duplicate records.
+
+### Procedure — steps 2
+
 for each record whose status is "duplicate":
   mark the record canonical.
   purge the record.
```
