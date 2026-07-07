---
name: oncall handoff
description: Give the next on-call engineer a running start at shift change by naming the busiest service and confirming every other service's health first, instead of handing over a shift with nothing but "good luck, check the dashboard."
triggers:
  - "run oncall handoff"
  - "prepare shift handoff"
  - "run the shift handoff pass"
---

# Oncall Handoff

The worst way to start an on-call shift is discovering, an hour in, that a
service has been quietly accumulating open incidents the whole time nobody
told you about. This skill closes that gap at the handoff boundary: it
pulls every service and every open incident, counts the total, identifies
which service is carrying the most open incidents right now, and checks
every service's health so the incoming engineer starts the shift already
knowing where to look first.

## When to invoke
- "run oncall handoff"
- "prepare shift handoff"
- "run the shift handoff pass"

Run this at the end of every shift, not just when the outgoing engineer
remembers to. A handoff that only happens when things are already on fire
defeats the point.

## Workflow
fetch services.
fetch open incidents.
Check: any services.
let open incident total be the number of open incidents.
let busiest service be the highest service by open incident count.
for each service:
  check the health of the service.
Post: "oncall handoff pass complete".

## Anti-Patterns
- Don't skip the per-service health check because the incident count
  "looks fine." A service can be unhealthy without an open incident yet
  filed against it — the health check is the part that catches that gap.
- Don't hand off verbally without running this pass first. The receipt is
  what the incoming engineer can actually act on; a verbal summary is
  whatever the outgoing engineer happened to remember.

## Report shape
The receipt states the open incident count and calls out the busiest
service, so the incoming engineer knows exactly where the shift's attention
is most likely needed first.
