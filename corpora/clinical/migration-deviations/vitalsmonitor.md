# Deviation: vitalsmonitor.meri

- Original: `vitals_monitor/SKILL.md`
- Ported: `vitalsmonitor.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 59 -> 65 (+16 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L11 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/6 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=43

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/vitals_monitor/SKILL.md
+++ skills/vitalsmonitor.meri
@@ -9,14 +9,14 @@
 
 # Vitals Monitor
 
-A vital sign reading is only as good as how recently it was taken — a
-patient who looked stable four hours ago is not the same as a patient who
-looks stable right now. This skill exists purely to keep that gap small.
-It rechecks the patient's vitals on a fixed cadence and escalates the
-instant the patient goes past the observation window without a fresh
-reading, rather than assuming yesterday's numbers still hold.
+> A vital sign reading is only as good as how recently it was taken — a
+> patient who looked stable four hours ago is not the same as a patient who
+> looks stable right now. This skill exists purely to keep that gap small.
+> It rechecks the patient's vitals on a fixed cadence and escalates the
+> instant the patient goes past the observation window without a fresh
+> reading, rather than assuming yesterday's numbers still hold.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a patient.
 - Output: either a confirmed fresh reading or an escalation for a patient
   who has gone stale.
@@ -28,7 +28,10 @@
 - "run vitals watch"
 
 ## Rules
-When a patient has been unmonitored for more than 4 hours, escalate the patient.
+
+### Rules — steps
+
+When a patient is flagged as unmonitored, escalate the patient.
 
 ## Workflow
 until the patient is monitored,
@@ -40,7 +43,7 @@
 ## Guarantees
 make sure the patient's last observed at is within the last 4 hours.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't treat a single fresh reading as the end of the watch — the loop
   exists because the patient goes stale again after the next observation
   window, not just once.
@@ -49,11 +52,14 @@
   staffing conversation.
 
 ## When NOT to use this skill
+
+### When NOT to use this skill — steps (( role: reference ))
+
 Use `triage patient` instead for a single point-in-time severity decision;
 reading freshness over time is a different question than how severe a
 reading is right now.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt records how many recheck cycles ran before the patient was
 confirmed current, or that the patient was escalated for going stale.
 
```
