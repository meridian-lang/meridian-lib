# Deviation: receiveshipment.meri

- Original: `receive_shipment/SKILL.md`
- Ported: `receiveshipment.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 22 -> 22 (+1 / -1)

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
- Operational inert: 1
- Unclassified inert: 0
- Inert categories: operational-procedure=1, reference-documentation=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `When this applies`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L12 `Human notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/receive_shipment/SKILL.md
+++ skills/receiveshipment.meri
@@ -8,7 +8,7 @@
 
 # Receive Shipment
 
-## When this applies
+## When this applies (( inert, role: applicability ))
 - "receive inbound shipment"
 - "shipment received"
 
```
