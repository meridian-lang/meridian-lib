# Deviation: cascadeclose.meri

- Original: `cascade_close/SKILL.md`
- Ported: `cascadeclose.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 24 -> 32 (+11 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L22 `DBA notes`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L22 `DBA notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/cascade_close/SKILL.md
+++ skills/cascadeclose.meri
@@ -8,17 +8,25 @@
 
 # Cascade Close
 
-## Invocation
+## Invocation (( role: procedure ))
+use judgment to follow the Invocation guidance:
 - "cascade close"
 - "orphaned audit rows"
 
 ## Transaction body
+use judgment to follow the Transaction body guidance:
+Check: any orphaned audit rows.
+
+### Transaction body — steps
+
 SQL: `psql -c "select key,table_name from audit_rows where status='orphaned'" --csv` to snapshot orphaned audit rows.
 fetch orphaned audit rows.
-Check: any orphaned audit rows.
+
+### Transaction body — steps 2
+
 Emit: "orphaned audit rows recorded for deterministic close".
 
-## DBA notes
+## DBA notes (( inert ))
 The source system owns physical cascade delete; Meridian records the deterministic
 audit close and refuses to invent a hidden datastore.
 
```
