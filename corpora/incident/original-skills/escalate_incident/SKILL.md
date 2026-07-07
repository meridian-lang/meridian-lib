---
name: escalate incident
description: Escalate an open incident the moment a matching alert re-fires for the same service, treating a repeat alert on an already-open incident as proof the first response didn't hold rather than as a duplicate to be dismissed.
triggers:
  - "escalate open incidents"
  - "escalate stalled incidents"
  - "run incident escalation"
---

# Escalate Incident

An incident that's already open and then sees its alert fire again on the
same service isn't a coincidence — it's a signal that whatever response
happened first didn't actually resolve the underlying issue. This skill
waits for exactly that re-fire event, matched on service name so it doesn't
escalate on an unrelated alert, and escalates the incident the moment it
sees it.

## When to invoke
- "escalate open incidents"
- "escalate stalled incidents"
- "run incident escalation"

## Workflow
fetch open incidents.
Check: at least 1 incident whose severity is "sev1".
for each incident:
  wait for event alert.fired matching the event's service name equals the incident's service name.
  escalate the incident.
Post: "incident escalation pass complete".

## Anti-Patterns
- Don't escalate on any re-fired alert regardless of service. The service
  name match exists so an unrelated alert on a different service doesn't
  trigger an escalation for an incident it has nothing to do with.
- Don't treat this skill as a substitute for `mitigate incident`.
  Escalating raises the incident's visibility; it doesn't apply a
  mitigation on its own.

## Guarantees
make sure at least 0 incidents whose status is "open".

## Report shape
The receipt names which incidents were escalated this pass and the
re-fired alert that triggered each escalation.
