# Deviation: fulfillorder.meri

- Original: `fulfill_order/SKILL.md`
- Ported: `fulfillorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 97%
- Lines: 31 -> 31 (+1 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `When this applies`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.

## Metrics
- Sections: 3/4 inert (75% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `When this applies`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L8 `Operator notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L22 `Checks`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.

## Unified diff

```diff
--- original-skills/fulfill_order/SKILL.md
+++ skills/fulfillorder.meri
@@ -8,7 +8,7 @@
 
 # Fulfill Order
 
-## When this applies
+## When this applies (( inert, role: applicability ))
 - "fulfill ERP orders"
 - "release shipments"
 
```
