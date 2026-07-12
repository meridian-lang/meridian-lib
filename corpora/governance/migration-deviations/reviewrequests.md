# Deviation: reviewrequests.meri

- Original: `review_requests/SKILL.md`
- Ported: `reviewrequests.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 55 -> 58 (+12 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L11 `When to invoke`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L45 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 37 non-blank ported lines
- Sections inert total: 3/5 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=6, structure=0, desugar=0, meaning=33

### Inert section details
- L11 `When to invoke`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L45 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/review_requests/SKILL.md
+++ skills/reviewrequests.meri
@@ -10,14 +10,14 @@
 
 # Review Requests
 
-A pending access request that nobody looks at for a week is worse than one
-that gets denied on day one — at least a denial gives the requester a clear
-next step. This skill exists to keep the human-in-the-loop part of access
-governance from silently backing up: it pulls the pending queue, checks that
-the backlog hasn't grown past a sane size, and hands the reviewer the front
-of the line rather than the whole pile.
+> A pending access request that nobody looks at for a week is worse than one
+> that gets denied on day one — at least a denial gives the requester a clear
+> next step. This skill exists to keep the human-in-the-loop part of access
+> governance from silently backing up: it pulls the pending queue, checks that
+> the backlog hasn't grown past a sane size, and hands the reviewer the front
+> of the line rather than the whole pile.
 
-## When to invoke
+## When to invoke (( role: reference ))
 - "review access requests"
 - "review pending requests"
 - "work the request queue"
@@ -27,6 +27,9 @@
 is the whole point.
 
 ## Rules
+
+### Rules — steps
+
 A reviewer may approve access requests whose queue position is at most 3.
 
 ## Workflow
@@ -37,7 +40,7 @@
   log an audit entry for the access request.
 Emit: "review requests pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't let a reviewer approve requests out of queue order just because a
   requester is persistent — queue position exists precisely so approval
   isn't first-come-loudest.
@@ -48,7 +51,7 @@
 ## Guarantees
 make sure at most 20 access requests whose status is "pending".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt lists which access requests were surfaced to the reviewer this
 pass, in queue order, so a reviewer can tell at a glance whether the backlog
 is shrinking or growing.
```
