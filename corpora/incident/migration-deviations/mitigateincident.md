# Deviation: mitigateincident.meri

- Original: `mitigate_incident/SKILL.md`
- Ported: `mitigateincident.meri`
- Tier: 2 (light edits)
- Similarity: 68%
- Lines: 52 -> 54 (+18 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L42 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 35 non-blank ported lines
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=32

### Inert section details
- L32 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/mitigate_incident/SKILL.md
+++ skills/mitigateincident.meri
@@ -9,14 +9,14 @@
 
 # Mitigate Incident
 
-The right mitigation for an incident depends entirely on how bad it is
-right now, not on which action feels safest to reach for. This skill
-encodes that judgment as a discretion table so the response scales with
-severity: a high-severity incident gets an immediate rollback of the
-latest deploy, a sev3 gets a traffic throttle instead of something more
-disruptive, and anything milder gets monitored and documented rather than
-mitigated at all. A status update goes out for every incident, but in the
-background — a mitigation action shouldn't wait on a status post to finish.
+> The right mitigation for an incident depends entirely on how bad it is
+> right now, not on which action feels safest to reach for. This skill
+> encodes that judgment as a discretion table so the response scales with
+> severity: a high-severity incident gets an immediate rollback of the
+> latest deploy, a sev3 gets a traffic throttle instead of something more
+> disruptive, and anything milder gets monitored and documented rather than
+> mitigated at all. A status update goes out for every incident, but in the
+> background — a mitigation action shouldn't wait on a status post to finish.
 
 ## When to invoke
 - "mitigate open incidents"
@@ -27,25 +27,27 @@
 fetch open incidents.
 
 !!! table (( ai-discretion ))
-| Condition                                  | Action                                    |
+| Condition                 | Action                  |
 | ------------------------------------------- | ------------------------------------------ |
-| the incident is high severity                | roll back the latest deploy immediately    |
-| the incident's severity is "sev3"            | throttle traffic to the affected service   |
-| *                                             | monitor and document                       |
+| the incident is high severity        | roll back the latest deploy immediately  |
+| the incident's severity is "sev3"      | throttle traffic to the affected service  |
+| *                       | monitor and document            |
 
 for each incident:
   in the background, post a status update for the incident.
 Post: "incident mitigation pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't roll back a deploy for a sev3 incident out of habit. The
   discretion table reserves the immediate rollback for high severity
   precisely because it is the most disruptive option.
 - Don't block the mitigation action on the status update finishing first.
-  The update runs in the background so a slow post-status call has no
-  chance to delay the actual mitigation.
 
-## Report shape
+### Anti-Patterns — steps (( role: reference ))
+
+The update runs in the background so a slow post-status call has no chance to delay the actual mitigation.
+
+## Report shape (( role: template ))
 The receipt records the mitigation action chosen per incident, so a
 follow-up review can confirm the severity-to-action mapping held for every
 case in this pass.
```
