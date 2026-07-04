# Deviation: monthendclose.meri

- Original: `month_end_close/SKILL.md`
- Ported: `monthendclose.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 24 -> 25 (+3 / -2)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L15 `Accounting notes`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1
- Judgment: 1 blocks, 0 lines

### Inert section details
- L15 `Accounting notes`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/month_end_close/SKILL.md
+++ skills/monthendclose.meri
@@ -8,7 +8,8 @@
 
 # Month End Close
 
-## When this applies
+## When this applies (( role: procedure ))
+use judgment to follow the When this applies guidance:
 - "month-end close"
 - "close accounting period"
 
@@ -18,7 +19,7 @@
 close the accounting period.
 Publish: "accounting period closed".
 
-## Accounting notes
+## Accounting notes (( inert ))
 The real-world phrase "soft close" is intentionally left as documentation; the
 compiled behavior uses an explicit period-close tool.
 
```
