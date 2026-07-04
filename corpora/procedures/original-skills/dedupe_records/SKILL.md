---
name: dedupe records
description: Mark duplicate records canonical and purge duplicate tails.
triggers:
  - "dedupe records"
  - "duplicate rows detected"
---

# Dedupe Records

## Use this when
- "dedupe records"
- "duplicate rows detected"

## Procedure (( role: procedure ))
fetch duplicate records.
Check: any duplicate records.
for each record whose status is "duplicate":
  mark the record canonical.
  purge the record.
Emit: "duplicate record pass complete".

## Postconditions (( role: invariants ))
make sure no records whose status is "duplicate".
