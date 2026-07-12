# Procedures Resolver

Routes a DBA request to the deterministic stored-procedure skill that owns it.

## Dispatch table

| trigger phrase | skill |
| --- | --- |
| reconcile ledger | reconcileledger |
| aging report | agingreport |
| dedupe records | deduperecords |
| cascade close | cascadeclose |
| rebuild lagging indexes | rebuildindex |
| validate constraints | validateconstraints |
| purge expired records | purgeexpired |
| settle ready batches | settlebatch |
| apply pending migrations | migrationapply |
| vacuum bloated tables | vacuumtables |
| retry failed batches | retryfailedbatch |
| checksum audit | checksumaudit |
| check ledger parity | ledgerparitywatch |

## Workflow

Look up the skill corresponding to the trigger phrase and emit the selected
skill id.
