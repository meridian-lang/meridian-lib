---
name: quality gate
description: Run the data-quality checks for every dataset due this pass and render a single green/red receipt instead of leaving the results scattered across individual check logs. This is the skill a downstream consumer should check before trusting a dataset, not the individual quality-check tool.
triggers:
  - "run quality gate"
  - "check data quality"
  - "run the quality gate pass"
---

# Quality Gate

Individual quality checks are useful, but nobody wants to read through a
dozen of them to answer "is today's data good enough to use?" This skill
runs quality checks across every dataset that's due, counts how many
passed, and renders a single threshold-aware receipt — green if anything
passed, red otherwise — so a downstream consumer or an on-call engineer can
answer that question in one glance instead of grepping through check logs.

## When to invoke
- "run quality gate"
- "check data quality"
- "run the quality gate pass"

## Tables
!!! table (( data table: thresholds ))
| name | floor |
| ---- | ----- |
| high | 100   |
| low  | 0     |

## Workflow
fetch datasets.
for each dataset:
  run quality checks on the dataset.
let passing count be the number of quality checks whose status is "passed".
bind quality report =
  ```
  quality-gate:
  [if passing count is more than 0]status: green[otherwise]status: red[end if]
  passing checks: {{ passing count }}
  ```
emit etl.quality_report with body = quality report.
- [ ] the passing count is at least 0
Emit: "quality gate pass complete".

## Anti-Patterns
- Don't treat a green gate as a guarantee that every dataset passed —
  it only means at least one check passed. Read the passing count, not
  just the color, before trusting a batch wholesale.
- Don't skip the gate for a habitually passing dataset. The thresholds
  table exists to catch the one run that finally breaks the streak.

## Guarantees
every emitted quality report contains "quality-gate".

## Report shape
The receipt opens with `quality-gate:`, reports `green` or `red`, and states
the passing-check count for this pass.
