# Deviation: agingreport.meri

- Original: `aging_report/SKILL.md`
- Ported: `agingreport.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 40 -> 46 (+13 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L36 `Trace shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L14 `Procedure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L36 `Trace shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/aging_report/SKILL.md
+++ skills/agingreport.meri
@@ -18,12 +18,7 @@
 | stale | review |
 | duplicate | merge |
 
-## Procedure
-fetch stale records.
-Check: any stale records.
-let stale count be the number of stale records.
-let oldest record be the oldest stale record.
-bind selected action = the action corresponding to the bucket "stale" in the table.
+## Procedure (( role: reference ))
 bind aging report =
   ```
   aging:
@@ -32,9 +27,20 @@
   selected action: {{ selected action }}
   stale count: {{ stale count }}
   ```
+
+### Procedure — steps
+
+fetch stale records.
+Check: any stale records.
+let stale count be the number of stale records.
+let oldest record be the oldest stale record.
+bind selected action = the action corresponding to the bucket "stale" in the table.
+
+### Procedure — steps 2
+
 Emit: aging report.
 
-## Trace shape
+## Trace shape (( role: template ))
 One row per aging bucket, followed by the deterministic action, the selected
 bucket, and the total stale count.
 
```
