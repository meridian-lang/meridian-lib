---
name: settle batch
description: Settle every ready batch exactly once, retrying transient failures until they clear.
triggers:
  - "settle ready batches"
  - "batch settlement"
---

# Settle Batch

## Invocation
- "settle ready batches"
- "batch settlement"

## Batch body
fetch ready batches.
Check: all batches have a name.
for each batch:
  settle the batch unless the batch is finalized.
  recover from any:
    until it is not the case that the batch is ready,
      retry the batch.
Emit: "ready batches settled".

## Postconditions
make sure no batches whose status is "failed".
