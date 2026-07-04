---
name: reconcile ledger
description: Reconcile ready ledger batches from a SQL-backed system.
triggers:
  - "reconcile ledger"
  - "settle ledger batches"
---

# Reconcile Ledger

## Invocation
- "reconcile ledger"
- "settle ledger batches"

## DBA notes
The operator starts from a SQL snapshot and then lets Meridian drive only the
declared deterministic settlement tools.

## Procedure
SQL: `psql -c "select id,status from ledger_batch where status='ready'" --csv` to snapshot ready batches.
fetch ready batches.
Check: all batches have a name.
for each batch:
  settle the batch.
Emit: "ledger batches reconciled".

## Assertions
no batches whose status is "failed".

## Output
The DBA expects a short reconciliation receipt and a list of settled batch ids.
