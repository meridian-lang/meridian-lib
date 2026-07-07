---
name: validate constraints
description: Fail fast when database constraints are violated, routing ambiguous cases to judgment.
triggers:
  - "validate constraints"
  - "constraint violated"
---

# Validate Constraints

## Invocation
- "validate constraints"
- "constraint violated"

## Procedure
fetch violated constraints.
Check: no constraints whose status is "violated".
for each constraint:
  if the constraint's table name is not empty and either the constraint's status is "violated" or the constraint's status is "pending",
    use judgment to classify the constraint violation and recommend the least destructive remediation that keeps referential integrity,
  otherwise,
    Note: "constraint check clean".
Emit: "constraints validated".

## Constraints
Constraint prose remains documentation; the executable guard is in the procedure.
