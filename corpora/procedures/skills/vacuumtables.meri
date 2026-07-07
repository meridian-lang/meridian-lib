---
name: vacuum tables
description: Vacuum bloated database tables in parallel and rebuild lagging indexes in the background.
triggers:
  - "vacuum bloated tables"
  - "run table maintenance"
---

# Vacuum Tables

## When this applies
- "vacuum bloated tables"
- "run table maintenance"

## Procedure
fetch database tables.
fetch lagging index jobs.
simultaneously:
  for each table whose row count exceeds the vacuum row threshold:
    vacuum the table.
  for each index job:
    in the background, rebuild the index job.
Emit: "table maintenance pass complete".

## Guarantees
make sure all database tables have a name.
