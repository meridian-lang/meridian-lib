---
name: aging report
description: Render a deterministic report over stale records, including the oldest offender.
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
let stale count be the number of stale records.
let oldest record be the oldest stale record.
bind selected action = the action corresponding to the bucket "stale" in the table.
bind aging report =
  ```
  aging:
  [for each row in table]- {{ row.bucket }} -> {{ row.action }}
  [end for]
  selected action: {{ selected action }}
  stale count: {{ stale count }}
  ```
Emit: aging report.

## Trace shape
One row per aging bucket, followed by the deterministic action, the selected
bucket, and the total stale count.
