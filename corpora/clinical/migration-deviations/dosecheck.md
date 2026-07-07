# Deviation: dosecheck.meri

- Original: `dose_check/SKILL.md`
- Ported: `dosecheck.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 58 -> 64 (+16 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L12 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/5 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L12 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/dose_check/SKILL.md
+++ skills/dosecheck.meri
@@ -9,15 +9,15 @@
 
 # Dose Check
 
-A single medication order can be perfectly safe on its own and still be the
-one that pushes a nurse's shift total past a sane limit — fatigue from
-giving dose after dose is a real risk on its own, independent of whether
-any individual order has a problem. This skill is the shift-total gate: it
-checks how many doses a nurse has already given against the daily limit,
-and only lets the next administration proceed when there is still room
-under that limit.
+> A single medication order can be perfectly safe on its own and still be the
+> one that pushes a nurse's shift total past a sane limit — fatigue from
+> giving dose after dose is a real risk on its own, independent of whether
+> any individual order has a problem. This skill is the shift-total gate: it
+> checks how many doses a nurse has already given against the daily limit,
+> and only lets the next administration proceed when there is still room
+> under that limit.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a nurse and the medication order they are about to give.
 - Output: either a cleared administration or a routed hand-off to another
   nurse.
@@ -29,6 +29,9 @@
 - "run dose limit check"
 
 ## Rules
+
+### Rules — steps
+
 A nurse may administer medication orders whose dose count is at most 2.
 
 ## Workflow
@@ -39,7 +42,7 @@
   Note: "dose limit reached for this nurse, hand off to another nurse".
 Emit: "dose check pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't round the dose count down "just this once" to squeeze in one more
   administration — the limit exists because of fatigue risk, not paperwork,
   and fatigue doesn't round down with it.
@@ -48,11 +51,14 @@
   hand-off.
 
 ## When NOT to use this skill
+
+### When NOT to use this skill — steps (( role: reference ))
+
 Use `medication administer` for the actual allergy and risk check on a
 specific order. This skill answers a different question — a running dose
 count for the nurse's whole shift, not the safety of any one order.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states the nurse's dose count against the limit and whether
 the administration cleared or was routed to another nurse.
 
```
