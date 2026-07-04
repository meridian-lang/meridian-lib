# Deviation: deduperecords.meri

- Original: `dedupe_records/SKILL.md`
- Ported: `deduperecords.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 25 -> 34 (+12 / -3)

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
--- original-skills/dedupe_records/SKILL.md
+++ skills/deduperecords.meri
@@ -8,18 +8,27 @@
 
 # Dedupe Records
 
-## Use this when
+## Use this when (( role: procedure ))
+use judgment to follow the Use this when guidance:
 - "dedupe records"
 - "duplicate rows detected"
 
 ## Procedure
+use judgment to follow the Procedure guidance:
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
 Emit: "duplicate record pass complete".
 
-## Postconditions
+## Postconditions (( role: procedure ))
+use judgment to follow the Postconditions guidance:
 make sure no records whose status is "duplicate".
 
```
