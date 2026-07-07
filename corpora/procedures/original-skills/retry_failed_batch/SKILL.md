---
name: retry failed batch
description: Retry failed batches with a bounded retry budget, skipping batches already finalized.
triggers:
  - "retry failed batches"
  - "reattempt batch settlement"
---

# Retry Failed Batch

## When this applies
- "retry failed batches"
- "reattempt batch settlement"

## Procedure
fetch failed batches.
Check: any batches whose status is "failed".
while any batches whose status is "failed",
  for each batch whose status is "failed":
    retry the batch unless the batch is finalized.
fetch ready batches.
for each batch:
  until it is not the case that the batch is ready,
    settle the batch.
Emit: "failed batch retry pass complete".

## Postconditions
make sure no batches whose status is "failed".
