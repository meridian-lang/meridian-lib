# Deviation: cascadeclose.meri

- Original: `cascade_close/SKILL.md`
- Ported: `cascadeclose.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 24 -> 33 (+11 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections inert total: 1/2 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Transaction body`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/cascade_close/SKILL.md
+++ skills/cascadeclose.meri
@@ -12,13 +12,22 @@
 - "cascade close"
 - "orphaned audit rows"
 
-## Transaction body
+## Transaction body (( role: reference ))
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
 
 ## DBA notes
+
+### DBA notes — steps (( role: reference ))
+
 The source system owns physical cascade delete; Meridian records the deterministic
 audit close and refuses to invent a hidden datastore.
 
```
