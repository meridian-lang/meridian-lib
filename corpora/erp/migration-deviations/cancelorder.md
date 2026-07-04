# Deviation: cancelorder.meri

- Original: `cancel_order/SKILL.md`
- Ported: `cancelorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 96%
- Lines: 24 -> 24 (+1 / -1)

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
- Sections: 2/3 inert (67% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `When this applies`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L15 `Controls`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.

## Unified diff

```diff
--- original-skills/cancel_order/SKILL.md
+++ skills/cancelorder.meri
@@ -8,7 +8,7 @@
 
 # Cancel Order
 
-## When this applies
+## When this applies (( inert, role: applicability ))
 - "cancel blocked orders"
 - "void ERP orders"
 
```
