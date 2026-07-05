# Deviation: validateconstraints.meri

- Original: `validate_constraints/SKILL.md`
- Ported: `validateconstraints.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 22 -> 22 (+1 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L13 `Constraints`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L13 `Constraints`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/validate_constraints/SKILL.md
+++ skills/validateconstraints.meri
@@ -17,6 +17,6 @@
 Check: no constraints whose status is "violated".
 Emit: "constraints validated".
 
-## Constraints
+## Constraints (( role: reference ))
 Constraint prose remains documentation; the executable guard is in the procedure.
 
```
