---
name: settle batch
description: Settle every ready batch exactly once.
triggers:
  - "settle ready batches"
  - "batch settlement"
---

# Settle Batch

## Invocation
- "settle ready batches"
- "batch settlement"

## Batch body (( role: procedure ))
fetch ready batches.
Check: all batches have a name.
for each batch:
  settle the batch.
Emit: "ready batches settled".

## Postconditions (( role: invariants ))
make sure no batches whose status is "failed".
