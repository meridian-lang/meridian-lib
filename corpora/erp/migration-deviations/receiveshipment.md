# Deviation: receiveshipment.meri

- Original: `receive_shipment/SKILL.md`
- Ported: `receiveshipment.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 22 -> 23 (+3 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L13 `Human notes`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1
- Judgment: 1 blocks, 0 lines

### Inert section details
- L13 `Human notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/receive_shipment/SKILL.md
+++ skills/receiveshipment.meri
@@ -8,7 +8,8 @@
 
 # Receive Shipment
 
-## When this applies
+## When this applies (( role: procedure ))
+use judgment to follow the When this applies guidance:
 - "receive inbound shipment"
 - "shipment received"
 
@@ -16,7 +17,7 @@
 Step: `ofbiz warehouse receive --today --json` to snapshot inbound manifests.
 Publish: "warehouse receiving manifest captured".
 
-## Human notes
+## Human notes (( inert ))
 Inbound receiving is intentionally shell-backed in this synthetic corpus because
 the source system exposes a manifest command rather than a first-class API call.
 
```
