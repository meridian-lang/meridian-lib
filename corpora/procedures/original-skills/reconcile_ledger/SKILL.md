---
name: reconcile ledger
description: Reconcile ready ledger batches from a SQL-backed system, skipping already-finalized work and deferring failures.
triggers:
  - "reconcile ledger"
  - "settle ledger batches"
---

# Reconcile Ledger

## When this applies
- "reconcile ledger"
- "settle ledger batches"

## DBA notes
The operator starts from a SQL snapshot and then lets Meridian drive only the
declared deterministic settlement tools.

## Procedure
SQL: `psql -c "select id,status from ledger_batch where status='ready'" --csv` to snapshot ready batches.
fetch ready batches.
Check: all batches have a name.
Check: at most 50 batches whose status is "ready".
for each batch:
  if the batch is finalized,
    Note: "batch already finalized, skipping settlement",
  otherwise,
    settle the batch.
    recover from any:
      Note: "settlement failed, deferring to next reconciliation pass".
Emit: "ledger batches reconciled".

## Assertions
no batches whose status is "failed".
validate that all batches have a ledger id.
