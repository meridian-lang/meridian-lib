---
name: access review freshness
description: Treat review freshness as a real governance control instead of a spreadsheet afterthought by checking the retained review history at the exact retention boundary the trace policy promises. Use this before granting that a resource's review posture is current, not after an auditor has already asked why the evidence went stale.
triggers:
  - "check access review freshness"
  - "run access review freshness"
  - "verify resource review currency"
parameters: resource
---

# Access Review Freshness

An access review is only useful as evidence while it is still fresh enough to
say something about the resource in front of you. This skill turns that idea
into a live control: it asks whether the resource still has review evidence
inside the retained boundary, and it treats the boundary itself as load-bearing
so the answer cannot quietly drift away from what the trace policy retains.

## Contract
- Input: a resource.
- Output: a review-freshness verdict at the retention boundary.
- Side effect: none beyond the emitted review status.

## When to invoke
- "check access review freshness"
- "run access review freshness"
- "verify resource review currency"

## Workflow
if across all runs, the access review step has ever succeeded,
  Emit: "access review freshness found historical review evidence".
if the resource's status is "active",
  if the access review step has succeeded within the last 30 days,
    Emit: "access review freshness found retained review evidence inside the boundary".
  otherwise,
    Emit: "access review freshness found no retained review evidence inside the boundary".
Emit: "access review freshness pass complete".

## Anti-Patterns
- Don't stretch a review window past the trace retention and still call the
  answer fresh. Once the evidence is outside retention, this skill no longer
  gets to claim it.
- Don't depend on payload details that the capture policy deliberately omits.
  The review-freshness check is written against retained history only.
- Don't use a cross-run "ever" hit as proof of freshness. Historical evidence
  and still-fresh evidence are separate branches here.

## Guarantees
This skill treats the exact 30-day retained boundary as the freshness edge and
records both the historical-evidence branch and the still-fresh branch
separately.

## Report shape
The receipt distinguishes historical review evidence from still-fresh review
evidence and records whether the resource stayed inside the exact retained
30-day review boundary.
