# Deviation: triagepatient.meri

- Original: `triage_patient/SKILL.md`
- Ported: `triagepatient.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 58 -> 58 (+10 / -10)

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
- L32 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L40 `When NOT to use this skill`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/6 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 1 blocks, 0 lines

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L40 `When NOT to use this skill`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/triage_patient/SKILL.md
+++ skills/triagepatient.meri
@@ -9,14 +9,14 @@
 
 # Triage Patient
 
-Triage is the one place in a ward where being slow is its own kind of
-mistake — a patient who is quietly deteriorating rarely announces it, and
-the vitals are usually the first place it shows. This skill pulls the
-patient's latest vital signs, escalates immediately the moment any one of
-them crosses its ceiling, and otherwise falls back to a human triage
-decision rather than guessing at a severity level from thresholds alone.
+> Triage is the one place in a ward where being slow is its own kind of
+> mistake — a patient who is quietly deteriorating rarely announces it, and
+> the vitals are usually the first place it shows. This skill pulls the
+> patient's latest vital signs, escalates immediately the moment any one of
+> them crosses its ceiling, and otherwise falls back to a human triage
+> decision rather than guessing at a severity level from thresholds alone.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a patient.
 - Output: either an immediate escalation or a recorded triage level chosen
   by a clinician.
@@ -37,7 +37,7 @@
   ask the user to choose between "admit", "observe", "discharge".
 Emit: "triage patient pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't wait for a second critical reading to confirm the first — a single
   vital sign past its ceiling is already the escalation trigger, not a
   suggestion to recheck first.
@@ -45,13 +45,13 @@
   already fired the escalation branch; the two paths are mutually
   exclusive by design, not a fallback chain.
 
-## When NOT to use this skill
+## When NOT to use this skill (( role: reference ))
 Use `vitals monitor` instead for the recurring background check that keeps
 watching a patient between triage passes — this skill is a single point-in
 -time decision, not the ongoing watch. Use `medication administer` once a
 triage level has already produced an order that needs to be given.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt records which branch fired — an immediate escalation or a
 human-chosen triage level — and the level itself when a human made the
 call.
```
