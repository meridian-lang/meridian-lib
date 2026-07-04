---
name: validate constraints
description: Fail fast when database constraints are violated.
triggers:
  - "validate constraints"
  - "constraint violated"
---

# Validate Constraints

## Invocation
- "validate constraints"
- "constraint violated"

## Procedure (( role: procedure ))
fetch violated constraints.
Check: no constraints whose status is "violated".
Emit: "constraints validated".

## Constraints (( inert, role: invariants ))
Constraint prose remains documentation; the executable guard is in the procedure.
