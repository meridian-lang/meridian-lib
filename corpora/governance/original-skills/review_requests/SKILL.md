---
name: review requests
description: Surface the front of the pending access-request queue to a human reviewer instead of letting the whole backlog pile up unattended. Bounds each pass to the top of the queue so a reviewer always sees a manageable batch, not the entire backlog at once.
triggers:
  - "review access requests"
  - "review pending requests"
  - "work the request queue"
parameters: reviewer, access request
---

# Review Requests

A pending access request that nobody looks at for a week is worse than one
that gets denied on day one — at least a denial gives the requester a clear
next step. This skill exists to keep the human-in-the-loop part of access
governance from silently backing up: it pulls the pending queue, checks that
the backlog hasn't grown past a sane size, and hands the reviewer the front
of the line rather than the whole pile.

## When to invoke
- "review access requests"
- "review pending requests"
- "work the request queue"

Run this on a recurring cadence (daily is typical) rather than only when
someone complains that a request is stuck. Catching a growing backlog early
is the whole point.

## Rules
A reviewer may approve access requests whose queue position is at most 3.

## Workflow
fetch pending access requests.
Check: at least 1 pending access request.
Check: at most 20 pending access requests.
for each access request whose queue position is at most 3:
  log an audit entry for the access request.
Emit: "review requests pass complete".

## Anti-Patterns
- Don't let a reviewer approve requests out of queue order just because a
  requester is persistent — queue position exists precisely so approval
  isn't first-come-loudest.
- Don't treat a passing run as "the queue is empty." A pass only clears the
  front three positions; a still-growing backlog behind them needs its own
  investigation, not another review pass.

## Guarantees
make sure at most 20 access requests whose status is "pending".

## Report shape
The receipt lists which access requests were surfaced to the reviewer this
pass, in queue order, so a reviewer can tell at a glance whether the backlog
is shrinking or growing.
