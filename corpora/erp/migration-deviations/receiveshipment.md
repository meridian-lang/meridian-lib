# Deviation: receiveshipment.meri

- Original: `receive_shipment/SKILL.md`
- Ported: `receiveshipment.meri`
- Tier: 1 (near-verbatim)
- Similarity: 96%
- Lines: 23 -> 23 (+1 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L13 `Human notes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L13 `Human notes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/receive_shipment/SKILL.md
+++ skills/receiveshipment.meri
@@ -17,7 +17,7 @@
 wait for signal "manifest_confirmed".
 Publish: "warehouse receiving manifest captured".
 
-## Human notes
+## Human notes (( role: reference ))
 Inbound receiving is intentionally shell-backed in this synthetic corpus because
 the source system exposes a manifest command rather than a first-class API call.
 
```
