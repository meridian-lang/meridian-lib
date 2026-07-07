# Deviation: qualitygate.meri

- Original: `quality_gate/SKILL.md`
- Ported: `qualitygate.meri`
- Tier: 2 (light edits)
- Similarity: 74%
- Lines: 59 -> 65 (+19 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L44 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/6 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L23 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/quality_gate/SKILL.md
+++ skills/qualitygate.meri
@@ -9,12 +9,12 @@
 
 # Quality Gate
 
-Individual quality checks are useful, but nobody wants to read through a
-dozen of them to answer "is today's data good enough to use?" This skill
-runs quality checks across every dataset that's due, counts how many
-passed, and renders a single threshold-aware receipt — green if anything
-passed, red otherwise — so a downstream consumer or an on-call engineer can
-answer that question in one glance instead of grepping through check logs.
+> Individual quality checks are useful, but nobody wants to read through a
+> dozen of them to answer "is today's data good enough to use?" This skill
+> runs quality checks across every dataset that's due, counts how many
+> passed, and renders a single threshold-aware receipt — green if anything
+> passed, red otherwise — so a downstream consumer or an on-call engineer can
+> answer that question in one glance instead of grepping through check logs.
 
 ## When to invoke
 - "run quality gate"
@@ -28,22 +28,28 @@
 | high | 100   |
 | low  | 0     |
 
-## Workflow
-fetch datasets.
-for each dataset:
-  run quality checks on the dataset.
-let passing count be the number of quality checks whose status is "passed".
+## Workflow (( role: reference ))
 bind quality report =
   ```
   quality-gate:
   [if passing count is more than 0]status: green[otherwise]status: red[end if]
   passing checks: {{ passing count }}
   ```
+
+### Workflow — steps
+
+fetch datasets.
+for each dataset:
+  run quality checks on the dataset.
+let passing count be the number of quality checks whose status is "passed".
+
+### Workflow — steps 2
+
 emit etl.quality_report with body = quality report.
 - [ ] the passing count is at least 0
 Emit: "quality gate pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't treat a green gate as a guarantee that every dataset passed —
   it only means at least one check passed. Read the passing count, not
   just the color, before trusting a batch wholesale.
@@ -53,7 +59,7 @@
 ## Guarantees
 every emitted quality report contains "quality-gate".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt opens with `quality-gate:`, reports `green` or `red`, and states
 the passing-check count for this pass.
 
```
