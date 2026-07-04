---
name: rebuild index
description: Rebuild lagging indexes after a deterministic age check.
triggers:
  - "rebuild lagging indexes"
  - "index job stale"
---

# Rebuild Index

## Use this when
- "rebuild lagging indexes"
- "index job stale"

## Procedure (( role: procedure ))
fetch lagging index jobs.
Check: any lagging index jobs.
for each index job:
  rebuild the index job.
Emit: "lagging index jobs rebuilt".

## Assertions (( role: invariants ))
make sure all index jobs have a name.
