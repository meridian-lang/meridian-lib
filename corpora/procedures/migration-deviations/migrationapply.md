# Deviation: migrationapply.meri

- Original: `migration_apply/SKILL.md`
- Ported: `migrationapply.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 27 -> 30 (+3 / -0)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- (none)

## Metrics
- Sections inert total: 0/2 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/migration_apply/SKILL.md
+++ skills/migrationapply.meri
@@ -13,6 +13,9 @@
 - "run schema migration"
 
 ## Procedure
+
+### Procedure — steps
+
 fetch failed migrations.
 for each migration:
   wait for approval of the migration from a database administrator.
```
