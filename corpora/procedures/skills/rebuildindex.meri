---
name: rebuild index
description: Rebuild lagging indexes after a deterministic age check, requiring a minimum backlog before running.
triggers:
  - "rebuild lagging indexes"
  - "index job stale"
---

# Rebuild Index

## Use this when
- "rebuild lagging indexes"
- "index job stale"

## Procedure
fetch lagging index jobs.
Check: any lagging index jobs.
Check: at least 1 index job whose status is "lagging".
for each index job:
  rebuild the index job.
Emit: "lagging index jobs rebuilt".

## Assertions
make sure all index jobs have a name.
confirm no index jobs whose status is "failed".
