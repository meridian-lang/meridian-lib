# Deviation: placeorder.meri

- Original: `place_order/SKILL.md`
- Ported: `placeorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 97%
- Lines: 37 -> 37 (+1 / -1)

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
- Sections: 4/5 inert (80% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `When this applies`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L8 `Operator notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L24 `Checks`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L27 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/place_order/SKILL.md
+++ skills/placeorder.meri
@@ -8,7 +8,7 @@
 
 # Place Order
 
-## When this applies
+## When this applies (( inert, role: applicability ))
 - "process open orders"
 - "place customer orders"
 
```
