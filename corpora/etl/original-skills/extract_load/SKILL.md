---
name: extract load
description: Pull a dataset out of the landing source, validate its schema against what the warehouse expects, and load it in — holding the dataset for replay rather than half-loading it if the sink call fails partway through. This is the plain-vanilla ETL path every other skill in this corpus assumes already ran once.
triggers:
  - "run extract load"
  - "extract and load datasets"
  - "run the extract-load pass"
---

# Extract Load

Most of what goes wrong in a data pipeline isn't the extraction — it's
loading a dataset whose schema silently drifted, or losing track of a load
that failed halfway. This skill keeps the ordinary path boring: fetch the
datasets that are due, validate each one's schema before touching the
warehouse, load it, and if the load itself fails, hold the dataset for
replay instead of leaving it in an ambiguous half-loaded state.

## When to invoke
- "run extract load"
- "extract and load datasets"
- "run the extract-load pass"

## Workflow
fetch datasets.
Check: all datasets have a name.
extract a dataset from the object store source.
validate the schema for the dataset.
load the dataset into the warehouse sink.
recover from load.failed:
  Note: "load failed, dataset held for replay".
Emit: "extract load pass complete".

## Anti-Patterns
- Don't load a dataset before its schema has been validated, even when the
  source is "usually fine." The validation step exists precisely for the
  runs where it isn't.
- Don't retry a failed load inline in a tight loop. Hold it for replay —
  `pipeline triage` is the skill that decides whether a failure is worth
  replaying at all.

## Guarantees
make sure all datasets have a name.

## Report shape
The receipt confirms the load outcome per dataset, and names anything held
for replay after a failed load call.
