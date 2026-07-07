---
name: shift handoff
description: Roll the whole active-patient census up into a single handoff receipt at the end of a shift, so the incoming team starts from one number instead of re-deriving the picture from the chart system themselves. Use this at every shift change, not only when the outgoing team feels like something is unusual.
triggers:
  - "run shift handoff"
  - "render shift handoff report"
---

# Shift Handoff

A shift change is exactly the moment a quiet problem gets lost — the
outgoing team knows what's held and why, and that context doesn't
transfer just because the incoming team can see the same chart system.
This skill exists to force the transfer explicitly: it counts the active
census, counts how many patients are currently held, and renders both
into one receipt the incoming team reads before touching a single chart.

## Contract
- Input: none — this skill reads the full active census itself.
- Output: a rendered handoff summary naming the active count and the held
  count.
- Side effect: none beyond the rendered summary — this is a read-only
  roll-up.

## When to invoke
- "run shift handoff"
- "render shift handoff report"

## Workflow
fetch active patients.
Check: at least 1 patient.
Check: at most 50 patients.
let patient count be the number of patients.
let held count be the number of patients whose status is "held".
bind handoff report =
  ```
  handoff-summary:
  active patients: {{ patient count }}
  held for review: {{ held count }}
  ```
Emit: handoff report.
Post: "shift handoff pass complete".

## Anti-Patterns
- Don't skip the handoff on the assumption that the outgoing shift
  mentioned everything verbally. A verbal note doesn't survive a second
  handoff down the line; the rendered receipt does.
- Don't let the held count stand in for an actual review of each held
  patient. The number points the incoming team at where to look, nothing
  more.

## When NOT to use this skill
Use `discharge review` for the actual discharge decision on a specific
held patient. This skill stops at the count.

## Guarantees
make sure at most 50 patients whose status is "held".

## Report shape
The receipt states the active census size and how many of those patients
are currently held, in one line each.
