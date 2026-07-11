# Deviation: oncallhandoff.meri

- Original: `oncall_handoff/SKILL.md`
- Ported: `oncallhandoff.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 51 -> 51 (+10 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L12 `When to invoke`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L31 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L39 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/4 (75% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=35

### Inert section details
- L12 `When to invoke`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L31 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L39 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/oncall_handoff/SKILL.md
+++ skills/oncallhandoff.meri
@@ -9,15 +9,15 @@
 
 # Oncall Handoff
 
-The worst way to start an on-call shift is discovering, an hour in, that a
-service has been quietly accumulating open incidents the whole time nobody
-told you about. This skill closes that gap at the handoff boundary: it
-pulls every service and every open incident, counts the total, identifies
-which service is carrying the most open incidents right now, and checks
-every service's health so the incoming engineer starts the shift already
-knowing where to look first.
+> The worst way to start an on-call shift is discovering, an hour in, that a
+> service has been quietly accumulating open incidents the whole time nobody
+> told you about. This skill closes that gap at the handoff boundary: it
+> pulls every service and every open incident, counts the total, identifies
+> which service is carrying the most open incidents right now, and checks
+> every service's health so the incoming engineer starts the shift already
+> knowing where to look first.
 
-## When to invoke
+## When to invoke (( role: reference ))
 - "run oncall handoff"
 - "prepare shift handoff"
 - "run the shift handoff pass"
@@ -36,7 +36,7 @@
   check the health of the service.
 Post: "oncall handoff pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't skip the per-service health check because the incident count
   "looks fine." A service can be unhealthy without an open incident yet
   filed against it — the health check is the part that catches that gap.
@@ -44,7 +44,7 @@
   what the incoming engineer can actually act on; a verbal summary is
   whatever the outgoing engineer happened to remember.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states the open incident count and calls out the busiest
 service, so the incoming engineer knows exactly where the shift's attention
 is most likely needed first.
```
