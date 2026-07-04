# Deviation: validateconstraints.meri

- Original: `validate_constraints/SKILL.md`
- Ported: `validateconstraints.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 22 -> 24 (+4 / -2)

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
- Judgment: 2 blocks, 0 lines

## Unified diff

```diff
--- original-skills/validate_constraints/SKILL.md
+++ skills/validateconstraints.meri
@@ -8,7 +8,8 @@
 
 # Validate Constraints
 
-## Invocation
+## Invocation (( role: procedure ))
+use judgment to follow the Invocation guidance:
 - "validate constraints"
 - "constraint violated"
 
@@ -17,6 +18,7 @@
 Check: no constraints whose status is "violated".
 Emit: "constraints validated".
 
-## Constraints
+## Constraints (( role: procedure ))
+use judgment to follow the Constraints guidance:
 Constraint prose remains documentation; the executable guard is in the procedure.
 
```
