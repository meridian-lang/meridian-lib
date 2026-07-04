# Deviation: cancelorder.meri

- Original: `cancel_order/SKILL.md`
- Ported: `cancelorder.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 24 -> 26 (+4 / -2)

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
--- original-skills/cancel_order/SKILL.md
+++ skills/cancelorder.meri
@@ -8,7 +8,8 @@
 
 # Cancel Order
 
-## When this applies
+## When this applies (( role: procedure ))
+use judgment to follow the When this applies guidance:
 - "cancel blocked orders"
 - "void ERP orders"
 
@@ -19,6 +20,7 @@
   cancel the order.
 Publish: "blocked orders cancelled".
 
-## Controls
+## Controls (( role: procedure ))
+use judgment to follow the Controls guidance:
 An already fulfilled order must not be cancelled by this runbook.
 
```
