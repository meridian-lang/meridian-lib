---
name: pipeline reliability watch
description: Watch the reliability trend of the pipeline the way an ETL operator actually needs it watched: by run-level success, by occurrence-level failure, and by an explicit sample-floor unknown when the history is still too thin to trust. Use this to keep reliability drift visible between incidents, not only after a broken load already pages someone.
triggers:
  - "run pipeline reliability watch"
  - "check pipeline reliability"
  - "monitor extract load reliability"
---

# Pipeline Reliability Watch

An ETL pipeline can look calm right up until the day the quiet failures stop
being rare and start being normal. The operator usually needs two different
views of that drift: whether whole runs are landing cleanly, and whether the
individual failure occurrences inside those runs are staying below a safe
background rate. This skill keeps both views visible and says "unknown" out
loud when the retained sample is still too small to support either claim.

## Contract
1. the extract step usually succeeds, checked every 1 days.
2. the load step rarely fails, checked every 1 days.

## When to invoke
- "run pipeline reliability watch"
- "check pipeline reliability"
- "monitor extract load reliability"

## Workflow
1. if the extract step succeeds in at least 90% of runs within the last 30 days,
  Emit: "pipeline reliability saw healthy run frequency".
2. if it is unknown whether:
  Emit: "pipeline reliability run frequency is indeterminate below the sample floor".
3. otherwise,
  Emit: "pipeline reliability saw unhealthy run frequency".
4. if the load step fails in at most 5% of occurrences within the last 30 days,
  Emit: "pipeline reliability saw healthy occurrence frequency".
5. if it is unknown whether:
  Emit: "pipeline reliability occurrence frequency is indeterminate below the sample floor".
6. otherwise,
  Emit: "pipeline reliability saw unhealthy occurrence frequency".
7. Emit: "pipeline reliability watch pass complete".

## Anti-Patterns
- Don't use the run-frequency branch to answer an occurrence-frequency
  question. A clean run can still hide too many noisy failures inside it.
- Don't treat an indeterminate sample-floor result as a green result. Thin
  history is uncertainty, not evidence of health.
- Don't move the cadence out of the Contract lines. The monitored claim needs
  to say when it is checked, not leave that to a side note.

## Guarantees
make sure the extract step succeeds in at least 90% of runs within the last 30 days otherwise:
  Emit: "pipeline reliability guarantee recorded a run-frequency breach".
make sure the load step fails in at most 5% of occurrences within the last 30 days otherwise:
  Emit: "pipeline reliability guarantee recorded an occurrence-frequency breach".

## Report shape
The receipt records one verdict for run frequency and one for occurrence
frequency, with a separate indeterminate path when the retained sample is still
too small to support the claim.
