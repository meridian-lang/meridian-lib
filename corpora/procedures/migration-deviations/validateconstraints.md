# Deviation: validateconstraints.meri

- Original: `validate_constraints/SKILL.md`
- Ported: `validateconstraints.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 27 -> 30 (+4 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L21 `Constraints`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 1/2 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=17

### Inert section details
- L21 `Constraints`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/validate_constraints/SKILL.md
+++ skills/validateconstraints.meri
@@ -13,6 +13,9 @@
 - "constraint violated"
 
 ## Procedure
+
+### Procedure — steps
+
 fetch violated constraints.
 Check: no constraints whose status is "violated".
 for each constraint:
@@ -22,6 +25,6 @@
     Note: "constraint check clean".
 Emit: "constraints validated".
 
-## Constraints
+## Constraints (( role: reference ))
 Constraint prose remains documentation; the executable guard is in the procedure.
 
```
