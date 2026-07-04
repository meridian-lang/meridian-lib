# Deviation: dunning.meri

- Original: `dunning/SKILL.md`
- Ported: `dunning.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 25 -> 34 (+12 / -3)

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
- Judgment: 3 blocks, 0 lines

## Unified diff

```diff
--- original-skills/dunning/SKILL.md
+++ skills/dunning.meri
@@ -8,18 +8,27 @@
 
 # Dunning
 
-## When operators call this
+## When operators call this (( role: procedure ))
+use judgment to follow the When operators call this guidance:
 - "run dunning"
 - "collect overdue invoices"
 
 ## Workflow
+use judgment to follow the Workflow guidance:
+Check: any unpaid invoices.
+
+### Workflow — steps
+
 Step: `ofbiz accounting dunning --dry-run --json` to snapshot overdue accounts.
 fetch unpaid invoices.
-Check: any unpaid invoices.
+
+### Workflow — steps 2
+
 for each invoice:
   collect payment for the invoice.
 Publish: "dunning collection pass complete".
 
-## Controls
+## Controls (( role: procedure ))
+use judgment to follow the Controls guidance:
 Do not contact customers whose account is under manual review.
 
```
