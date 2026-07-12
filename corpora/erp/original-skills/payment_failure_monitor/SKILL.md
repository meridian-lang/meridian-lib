---
name: payment failure monitor
description: Keep payment instability visible before it turns into a full dunning wave by combining streak detection, statistical health, and an explicit unknown arm when the retained history is still too thin to trust. Use this for live payment reliability monitoring, not only after a collector has already noticed invoices piling up unpaid.
triggers:
  - "run payment failure monitor"
  - "monitor payment failures"
  - "check payment retry health"
parameters: invoice
---

# Payment Failure Monitor

Payment trouble rarely arrives as one clean failure. More often it starts as a
thin run history, then a failure streak, then a whole queue of invoices that
technically still looks "active" while the collector already knows something is
wrong. This skill keeps those stages separate: it monitors the overall payment
success rate, treats streaks as their own signal, and preserves the unknown
state that flows transitively through a derived invoice-health adjective.

## Contract
the payment step succeeds in at least 90% of runs within the last 30 days.

## When to invoke
- "run payment failure monitor"
- "monitor payment failures"
- "check payment retry health"

## Workflow
if the payment step has failed 3 times in a row,
  Publish: "payment failure monitor saw a live payment failure streak".
if the invoice is unpaid,
  if the payment step succeeds in at least 90% of runs within the last 30 days,
    Publish: "payment failure monitor saw healthy invoice history".
  if it is unknown whether:
    Publish: "payment failure monitor lacks enough retained history for the invoice".
  otherwise,
    Publish: "payment failure monitor saw unhealthy invoice history".
Publish: "payment failure monitor pass complete".

## Anti-Patterns
- Don't use the payment-success monitor to explain away a live streak. A good
  long-run percentage can still coexist with an active short-run failure chain.
- Don't treat the unknown branch as noise. The derived invoice adjective is
  transitively indeterminate on purpose when the payment history is still too
  thin.
- Don't move the monitored assertion's cadence into the skill text. This skill
  relies on the default monitor cadence from the trace configuration.

## Guarantees
This skill preserves the live failure streak as its own signal and keeps the
thin-history case explicit instead of letting the statistical branch quietly
default to a healthy answer.

## Report shape
The receipt separately records a live payment streak, a healthy derived invoice
state, an explicit unknown state from thin retained history, and the default
fallback branch when the invoice history is unhealthy.
