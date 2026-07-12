---
name: handoff reliability monitor
description: Monitor whether shift handoffs are landing reliably enough to trust, while keeping patient-sensitive trace payloads hashed or redacted and routing the ambiguous cases through a tightly scoped judgment boundary. Use this between shift summaries, not only after an omitted handoff detail has already become a safety event.
triggers:
  - "run handoff reliability monitor"
  - "check handoff reliability"
  - "monitor shift handoff quality"
tools: patient.list, vitals.read
---

# Handoff Reliability Monitor

The dangerous handoff is not the loudly broken one. It is the handoff that
looks routine enough to skip a second thought while one patient detail quietly
falls out of the chain. This skill monitors handoff reliability as an ongoing
signal, escalates clearly unmonitored patients deterministically, and leaves
the genuinely ambiguous follow-up cases to a judgment step whose tool scope is
kept intentionally narrow.

## Contract
the handoff step succeeds in at least 90% of runs within the last 30 days, checked every 4 hours.

## When to invoke
- "run handoff reliability monitor"
- "check handoff reliability"
- "monitor shift handoff quality"

## Tools Used
- list the active census (`patient.list`)
- read current vital trends (`vitals.read`)

## Workflow
1. fetch active patients.
2. for each patient:
  1. read the vital signs for the patient.
  2. if the patient is unmonitored,
    escalate the patient.
  3. otherwise,
    use judgment to decide whether the patient needs an extra handoff follow-up based on the latest vital trend and hold status.
3. Emit: "handoff reliability monitor pass complete".

## Anti-Patterns
- Don't treat the monitor as a substitute for the deterministic unmonitored
  escalation. The judgment step is only for the ambiguous follow-up cases.
- Don't widen the judgment tool scope just because more context would be
  convenient. This monitor keeps the witnessing boundary narrow on purpose.
- Don't store full patient payloads when the trace only needs hashes or
  redacted fields to witness the handoff path.

## Guarantees
make sure at most 50 patients.

## Report shape
The receipt records the monitor outcome, every deterministic escalation for an
unmonitored patient, and any privacy-scoped judgment follow-up decision needed
for a borderline handoff.
