# Deviation: agingreport.meri

- Original: `aging_report/SKILL.md`
- Ported: `agingreport.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 34 -> 42 (+11 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L33 `Trace shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L33 `Trace shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/aging_report/SKILL.md
+++ skills/agingreport.meri
@@ -8,7 +8,8 @@
 
 # Aging Report
 
-## Invocation
+## Invocation (( role: procedure ))
+use judgment to follow the Invocation guidance:
 - "aging report"
 - "stale record report"
 
@@ -19,7 +20,7 @@
 | duplicate | merge |
 
 ## Procedure
-fetch stale records.
+use judgment to follow the Procedure guidance:
 Check: any stale records.
 bind aging report =
   ```
@@ -27,8 +28,15 @@
   [for each row in table]- {{ row.bucket }} -> {{ row.action }}
   [end for]
   ```
+
+### Procedure — steps
+
+fetch stale records.
+
+### Procedure — steps 2
+
 Emit: aging report.
 
-## Trace shape
+## Trace shape (( inert, role: template ))
 One row per aging bucket, followed by the deterministic action.
 
```
