---
name: triage alert
description: Triage every firing alert by paging the on-call engineer immediately for anything critical, and routing the rest to judgment so a borderline alert gets a real severity-and-service assessment instead of either a reflexive page or a shrug. This is the first thing that touches a new alert before anyone decides what to do about it.
triggers:
  - "triage firing alerts"
  - "triage alerts"
  - "run alert triage"
---

# Triage Alert

A firing alert is a claim, not a verdict — some of them are genuinely
critical and need a human paged in the next thirty seconds, and some of
them are noisy signals that deserve a second look before anyone's phone
buzzes. This skill draws that line mechanically for the clear-cut critical
case (page immediately, then wait for an acknowledgment) and defers to
judgment for everything else, weighing the alert's severity against the
service it fired on rather than applying a blanket rule.

## When to invoke
- "triage firing alerts"
- "triage alerts"
- "run alert triage"

## Workflow
fetch firing alerts.
for each alert:
  if the alert is critical,
    page the oncall engineer for the alert.
    wait for signal "alert.acknowledged",
  otherwise,
    use judgment to classify the alert and recommend a response, weighing its severity and service name before escalating.
Post: "alert triage pass complete".

## Anti-Patterns
- Don't page on-call for every firing alert regardless of severity. Paging
  fatigue from noisy non-critical alerts is exactly what erodes trust in
  the next genuinely critical page.
- Don't let a non-critical alert sit unclassified because judgment "will
  get to it eventually." The judgment call is the response for that alert,
  not a deferral of one.

## Guarantees
make sure any alerts whose status is "firing".

## Report shape
The receipt separates paged critical alerts from alerts routed to judgment,
so an on-call engineer reviewing the pass can see which alerts got an
automatic page versus a reasoned call.
