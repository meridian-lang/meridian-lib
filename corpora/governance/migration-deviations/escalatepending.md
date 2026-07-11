# Deviation: escalatepending.meri

- Original: `escalate_pending/SKILL.md`
- Ported: `escalatepending.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 40 -> 43 (+12 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L26 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=26

### Inert section details
- L26 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/escalate_pending/SKILL.md
+++ skills/escalatepending.meri
@@ -8,33 +8,36 @@
 
 # Escalate Pending
 
-A request that's been sitting untouched for a week has already failed the
-normal review path — waiting for `review requests` to eventually get to it
-is no longer the right response. This skill's whole job is to catch that
-failure mode: once a pending request crosses the seven-day mark, it gets
-escalated automatically rather than waiting on a reviewer who may not know
-it's there.
+> A request that's been sitting untouched for a week has already failed the
+> normal review path — waiting for `review requests` to eventually get to it
+> is no longer the right response. This skill's whole job is to catch that
+> failure mode: once a pending request crosses the seven-day mark, it gets
+> escalated automatically rather than waiting on a reviewer who may not know
+> it's there.
 
 ## When to invoke
 - "escalate pending requests"
 - "escalate overdue requests"
 
 ## Rules
-When an access request has been pending for more than 7 days, escalate the access request.
+
+### Rules — steps
+
+When an access request is flagged as overdue, escalate the access request.
 
 ## Workflow
 fetch pending access requests.
 wait for event access.reviewed matching status is "granted".
 Emit: "escalate pending pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't reset the pending clock by re-submitting the same request under a
   new identifier just to dodge the escalation window — the seven-day rule
   exists to surface exactly that kind of stuck request.
 - Don't treat an escalation as a denial. Escalating hands the decision up a
   level; it doesn't make the decision itself.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt names which requests crossed the seven-day threshold this pass
 and confirms whether the escalation event fired.
 
```
