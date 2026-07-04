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

## Procedure (( role: procedure ))
fetch stale records.
Check: any stale records.
bind aging report =
  ```
  aging:
  [for each row in table]- {{ row.bucket }} -> {{ row.action }}
  [end for]
  ```
Emit: aging report.

## Trace shape (( inert, role: template ))
One row per aging bucket, followed by the deterministic action.
