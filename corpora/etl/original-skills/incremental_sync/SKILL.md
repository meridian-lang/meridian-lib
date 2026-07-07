---
name: incremental sync
description: Sync each dataset's watermark forward incrementally, retrying until it's actually fresh rather than declaring success after one extraction attempt, and skip a dataset entirely once it's flagged stale rather than syncing data nobody trusts anymore.
triggers:
  - "run incremental sync"
  - "sync dataset watermarks"
  - "run the watermark sync pass"
---

# Incremental Sync

A watermark-based sync that runs once and moves on can leave a dataset just
short of current if the extraction only pulls part of the backlog. This
skill keeps retrying the extraction until the watermark actually reports
fresh, and it treats a dataset flagged stale as out of scope for this pass
entirely — syncing a stale dataset's watermark forward would make it look
current without making its data trustworthy again.

## When to invoke
- "run incremental sync"
- "sync dataset watermarks"
- "run the watermark sync pass"

## Workflow
fetch datasets.
Check: any datasets.
for each dataset:
  read the watermark for the dataset.
  until it is not the case that the watermark is fresh,
    extract a dataset from the object store source unless the dataset is stale.
Emit: "incremental sync pass complete".

## Anti-Patterns
- Don't call a single extraction "synced." The retry loop exists because
  one extraction call rarely closes the whole gap between the last
  watermark and the current one.
- Don't bypass the stale-dataset skip to "catch it up anyway." A stale
  dataset needs `schema evolution` or `dedupe upsert` first, not a
  watermark push that hides the underlying problem.

## Guarantees
make sure no datasets whose status is "stale".

## Report shape
The receipt confirms each dataset's watermark is fresh at the end of the
pass, or names which ones were skipped because they were flagged stale.
