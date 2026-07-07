---
name: purge expired
description: Purge stale records in bounded deterministic order, capped at the configured retry count for failures.
triggers:
  - "purge expired records"
  - "retention cleanup"
---

# Purge Expired

## Use this when
- "purge expired records"
- "retention cleanup"

## Procedure
fetch stale records.
Check: any stale records.
Check: at most 500 stale records.
for each the first 100 records whose status is "stale" sorted by updated at, oldest first:
  purge the record.
recover from any:
  Emit: "expired record purge failed".
Emit: "expired records purged".

## Operator notes
The limit of 100 mirrors a stored procedure batch size and keeps replay bounded.
