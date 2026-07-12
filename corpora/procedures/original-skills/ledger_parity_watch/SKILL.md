---
name: ledger parity watch
description: Watch reconciliation parity as a standing DBA control instead of waiting for an end-of-day surprise, and keep a text receipt that explains which branch fired using the compound note form. Use this when ledger drift needs to be visible continuously, not only after a failed settle pass already made the discrepancy expensive.
triggers:
  - "run ledger parity watch"
  - "check ledger parity"
  - "monitor reconciliation parity"
parameters: ledger
---

# Ledger Parity Watch

Parity drift is easy to dismiss when it shows up once and expensive to ignore
when it repeats quietly for a whole day. This skill gives the ledger a running
parity watch: it evaluates the recent parity history, falls back cleanly when
that history is too thin to decide, and records the outcome explicitly so the
operator can inspect which branch fired without reconstructing it from raw
trace events alone.

## Contract
- Input: a ledger.
- Output: a parity receipt describing whether the ledger stayed within the
  configured occurrence threshold.
- Side effect: a blocking parity assert can recover and leave a deferred note
  instead of disappearing into a failed run.

## When to invoke
- "run ledger parity watch"
- "check ledger parity"
- "monitor reconciliation parity"

## Workflow
let the parity receipt be "parity watch opened".
if the parity step succeeds in at least 99% of occurrences within the last 30 days,
  Emit: "ledger parity stayed within threshold".
otherwise,
  Emit: "ledger parity is below threshold or the retained sample is still indeterminate".
assert the parity step succeeds in at least 99% of occurrences within the last 30 days otherwise:
  Emit: "blocking ledger parity assertion failed".
recover from any:
  Emit: "ledger parity check deferred after the blocking assertion failure".
proceed, and note "; parity watch pass complete" in the parity receipt.
Emit: "ledger parity watch pass complete".

## Anti-Patterns
- Don't reduce a parity watch to the last settle result. A ledger can clear one
  pass and still be drifting over the retained occurrence history.
- Don't treat the fallback branch as equivalent to "false". The otherwise path
  deliberately absorbs both a real threshold breach and a still-thin sample.
- Don't rebuild the text receipt by hand in downstream tooling. The receipt
  binding is part of the workflow so the result stays auditable.

## Guarantees
This skill leaves an explicit emitted record for the healthy branch, the K3
fallback branch, the blocking assertion failure, and the recovery-driven
deferral so the parity outcome stays inspectable after the run.

## Report shape
The emitted record states whether parity stayed within threshold, whether the
watch fell back because the retained sample stayed indeterminate or breached the
threshold, and whether the blocking parity assertion had to recover.
