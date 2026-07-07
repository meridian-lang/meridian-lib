# Deviation: postmortemrender.meri

- Original: `postmortem_render/SKILL.md`
- Ported: `postmortemrender.meri`
- Tier: 2 (light edits)
- Similarity: 74%
- Lines: 59 -> 65 (+19 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L43 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/6 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L23 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/postmortem_render/SKILL.md
+++ skills/postmortemrender.meri
@@ -9,12 +9,12 @@
 
 # Postmortem Render
 
-A postmortem written for a single incident is useful to the team that lived
-through it; a tier classification across a batch of postmortems is what a
-leadership review actually reads. This skill publishes a postmortem for
-every open incident and then rolls the batch up by counting sev1
-incidents against a floor — enough sev1s and the batch reads as
-high-impact, otherwise it reads as low.
+> A postmortem written for a single incident is useful to the team that lived
+> through it; a tier classification across a batch of postmortems is what a
+> leadership review actually reads. This skill publishes a postmortem for
+> every open incident and then rolls the batch up by counting sev1
+> incidents against a floor — enough sev1s and the batch reads as
+> high-impact, otherwise it reads as low.
 
 ## When to invoke
 - "render postmortem"
@@ -28,21 +28,27 @@
 | high | 2     |
 | low  | 0     |
 
-## Workflow
-fetch open incidents.
-for each incident:
-  publish a postmortem for the incident.
-let sev1 count be the number of incidents whose severity is "sev1".
+## Workflow (( role: reference ))
 bind postmortem report =
   ```
   postmortem-summary:
   [if sev1 count is more than 0]tier: high[otherwise]tier: low[end if]
   sev1 incidents: {{ sev1 count }}
   ```
+
+### Workflow — steps
+
+fetch open incidents.
+for each incident:
+  publish a postmortem for the incident.
+let sev1 count be the number of incidents whose severity is "sev1".
+
+### Workflow — steps 2
+
 emit incident.postmortem_report with body = postmortem report.
 Post: "postmortem render pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't skip publishing a postmortem for a sev3 incident because the tier
   only cares about sev1 counts. Every incident this skill fetches gets a
   postmortem; the tier classification is a summary on top, not a filter.
@@ -53,7 +59,7 @@
 ## Guarantees
 every emitted postmortem report contains "postmortem-summary".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states the impact tier — high or low — and the sev1 incident
 count that tier was computed from.
 
```
