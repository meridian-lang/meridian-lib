---
name: purge expired
description: Purge stale records in bounded deterministic order.
triggers:
  - "purge expired records"
  - "retention cleanup"
---

# Purge Expired

## Use this when
- "purge expired records"
- "retention cleanup"

## Procedure (( role: procedure ))
fetch stale records.
Check: any stale records.
for each the first 100 records whose status is "stale" sorted by updated at, oldest first:
  purge the record.
recover from any:
  Emit: "expired record purge failed".
Emit: "expired records purged".

## Operator notes (( inert ))
The limit of 100 mirrors a stored procedure batch size and keeps replay bounded.
