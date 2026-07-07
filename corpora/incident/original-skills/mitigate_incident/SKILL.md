---
name: mitigate incident
description: Pick a mitigation action for every open incident based on how severe it actually is — an immediate rollback for high severity, a traffic throttle for sev3, and a monitor-and-document holding pattern for everything else — while keeping stakeholders updated in the background instead of blocking mitigation on writing a status post.
triggers:
  - "mitigate open incidents"
  - "apply incident mitigation"
  - "run the incident mitigation pass"
---

# Mitigate Incident

The right mitigation for an incident depends entirely on how bad it is
right now, not on which action feels safest to reach for. This skill
encodes that judgment as a discretion table so the response scales with
severity: a high-severity incident gets an immediate rollback of the
latest deploy, a sev3 gets a traffic throttle instead of something more
disruptive, and anything milder gets monitored and documented rather than
mitigated at all. A status update goes out for every incident, but in the
background — a mitigation action shouldn't wait on a status post to finish.

## When to invoke
- "mitigate open incidents"
- "apply incident mitigation"
- "run the incident mitigation pass"

## Workflow
fetch open incidents.

!!! table (( ai-discretion ))
| Condition                                  | Action                                    |
| ------------------------------------------- | ------------------------------------------ |
| the incident is high severity                | roll back the latest deploy immediately    |
| the incident's severity is "sev3"            | throttle traffic to the affected service   |
| *                                             | monitor and document                       |

for each incident:
  in the background, post a status update for the incident.
Post: "incident mitigation pass complete".

## Anti-Patterns
- Don't roll back a deploy for a sev3 incident out of habit. The
  discretion table reserves the immediate rollback for high severity
  precisely because it is the most disruptive option.
- Don't block the mitigation action on the status update finishing first.
  The update runs in the background so a slow post-status call has no
  chance to delay the actual mitigation.

## Report shape
The receipt records the mitigation action chosen per incident, so a
follow-up review can confirm the severity-to-action mapping held for every
case in this pass.
