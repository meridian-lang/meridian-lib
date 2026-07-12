# Deviation: dischargereview.meri

- Original: `discharge_review/SKILL.md`
- Ported: `dischargereview.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 60 -> 66 (+15 / -9)

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
- generated_loc: 44 non-blank ported lines
- Sections inert total: 3/5 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=7, structure=0, desugar=0, meaning=38

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/discharge_review/SKILL.md
+++ skills/dischargereview.meri
@@ -9,14 +9,14 @@
 
 # Discharge Review
 
-A hold on a patient exists because someone with more context than a
-discharge checklist decided the patient wasn't ready yet — a discharge
-that goes through anyway defeats the entire point of placing the hold in
-the first place. This skill enforces that: a held patient is blocked from
-discharge by default, and the only path around it is an attending's own
-override, not a blanket policy exception.
+> A hold on a patient exists because someone with more context than a
+> discharge checklist decided the patient wasn't ready yet — a discharge
+> that goes through anyway defeats the entire point of placing the hold in
+> the first place. This skill enforces that: a held patient is blocked from
+> discharge by default, and the only path around it is an attending's own
+> override, not a blanket policy exception.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a patient being considered for discharge and the clinician
   reviewing it.
 - Output: either a completed discharge, a block on an active hold, or an
@@ -29,6 +29,9 @@
 - "discharge patient"
 
 ## Rules
+
+### Rules — steps
+
 A patient with status "held" must not be discharged.
 A clinician with role "attending" may discharge a patient with an active hold.
 
@@ -40,7 +43,7 @@
   Note: "no active hold, discharge proceeds normally".
 Emit: "discharge review pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't let a nurse or resident override a hold — the override path exists
   for an attending's own sign-off, not for whoever happens to be at the
   bedside.
@@ -49,11 +52,14 @@
   pre-clear the next.
 
 ## When NOT to use this skill
+
+### When NOT to use this skill — steps (( role: reference ))
+
 Use `triage patient` earlier in the stay when the question is severity,
 not discharge readiness — a hold decision and a triage decision answer
 different questions at different points in the stay.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states whether the discharge went through cleanly, was
 blocked by an active hold, or proceeded only after an attending's
 override.
```
