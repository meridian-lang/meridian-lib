---
name: aging report
description: Render a deterministic report over stale records.
triggers:
  - "aging report"
  - "stale record report"
---

# Aging Report

## Invocation
- "aging report"
- "stale record report"

## Tables
| bucket | action |
| --- | --- |
| stale | review |
| duplicate | merge |

## Procedure
fetch stale records.
Check: any stale records.
bind aging report =
  ```
  aging:
  [for each row in table]- {{ row.bucket }} -> {{ row.action }}
  [end for]
  ```
Emit: aging report.

## Trace shape
One row per aging bucket, followed by the deterministic action.
