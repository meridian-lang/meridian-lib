# Deviation: escalateincident.meri

- Original: `escalate_incident/SKILL.md`
- Ported: `escalateincident.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 46 -> 46 (+8 / -8)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L24 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=3, structure=0, desugar=0, meaning=28

### Inert section details
- L24 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/escalate_incident/SKILL.md
+++ skills/escalateincident.meri
@@ -9,12 +9,12 @@
 
 # Escalate Incident
 
-An incident that's already open and then sees its alert fire again on the
-same service isn't a coincidence — it's a signal that whatever response
-happened first didn't actually resolve the underlying issue. This skill
-waits for exactly that re-fire event, matched on service name so it doesn't
-escalate on an unrelated alert, and escalates the incident the moment it
-sees it.
+> An incident that's already open and then sees its alert fire again on the
+> same service isn't a coincidence — it's a signal that whatever response
+> happened first didn't actually resolve the underlying issue. This skill
+> waits for exactly that re-fire event, matched on service name so it doesn't
+> escalate on an unrelated alert, and escalates the incident the moment it
+> sees it.
 
 ## When to invoke
 - "escalate open incidents"
@@ -29,7 +29,7 @@
   escalate the incident.
 Post: "incident escalation pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't escalate on any re-fired alert regardless of service. The service
   name match exists so an unrelated alert on a different service doesn't
   trigger an escalation for an incident it has nothing to do with.
@@ -40,7 +40,7 @@
 ## Guarantees
 make sure at least 0 incidents whose status is "open".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt names which incidents were escalated this pass and the
 re-fired alert that triggered each escalation.
 
```
