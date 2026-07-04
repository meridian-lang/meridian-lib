---
name: cascade close
description: Close orphaned audit rows left by upstream cascade deletes.
triggers:
  - "cascade close"
  - "orphaned audit rows"
---

# Cascade Close

## Invocation
- "cascade close"
- "orphaned audit rows"

## Transaction body (( role: procedure ))
SQL: `psql -c "select key,table_name from audit_rows where status='orphaned'" --csv` to snapshot orphaned audit rows.
fetch orphaned audit rows.
Check: any orphaned audit rows.
Emit: "orphaned audit rows recorded for deterministic close".

## DBA notes (( inert ))
The source system owns physical cascade delete; Meridian records the deterministic
audit close and refuses to invent a hidden datastore.
