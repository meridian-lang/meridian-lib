# Deviation: cancelorder.meri

- Original: `cancel_order/SKILL.md`
- Ported: `cancelorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 24 -> 27 (+3 / -0)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections inert total: 0/2 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/cancel_order/SKILL.md
+++ skills/cancelorder.meri
@@ -20,5 +20,8 @@
 Publish: "blocked orders cancelled".
 
 ## Controls
+
+### Controls — steps (( role: reference ))
+
 An already fulfilled order must not be cancelled by this runbook.
 
```
