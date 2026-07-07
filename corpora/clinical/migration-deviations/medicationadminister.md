# Deviation: medicationadminister.meri

- Original: `medication_administer/SKILL.md`
- Ported: `medicationadminister.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 65 -> 74 (+19 / -10)

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
- L44 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L62 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/4 (75% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L12 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L62 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/medication_administer/SKILL.md
+++ skills/medicationadminister.meri
@@ -9,15 +9,15 @@
 
 # Medication Administer
 
-A wrong medication reaching a patient is rarely a single mistake — it is
-usually a chain of small skips: the allergy list wasn't re-checked, the
-order's risk tier wasn't looked at, or a high-risk order went in without a
-second set of eyes. This skill is that second set of eyes. It checks the
-order against the patient's allergy history before anything is given,
-and it holds any high-risk order for an attending's approval rather than
-trusting a single nurse's judgment call under time pressure.
+> A wrong medication reaching a patient is rarely a single mistake — it is
+> usually a chain of small skips: the allergy list wasn't re-checked, the
+> order's risk tier wasn't looked at, or a high-risk order went in without a
+> second set of eyes. This skill is that second set of eyes. It checks the
+> order against the patient's allergy history before anything is given,
+> and it holds any high-risk order for an attending's approval rather than
+> trusting a single nurse's judgment call under time pressure.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a patient, the medication order to give, and the nurse giving it.
 - Output: either a completed administration or a held order pending
   attending approval.
@@ -29,10 +29,16 @@
 - "give medication order"
 
 ## Rules
+
+### Rules — steps
+
 A medication order with allergy check "conflict" must not be administered.
 A high risk medication order must be approved by an attending before administration.
 
 ## Workflow
+
+### Workflow — steps
+
 check the allergy history for the medication order.
 if the medication order is cleared,
   administer the medication order.
@@ -43,7 +49,7 @@
 log an audit entry for the medication order.
 Emit: "medication administer pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't override an allergy conflict because the reaction "was mild last
   time" — a documented allergy stays a hard stop regardless of how the last
   exposure went.
@@ -52,13 +58,16 @@
   dose, not as paperwork afterward.
 
 ## When NOT to use this skill
+
+### When NOT to use this skill — steps (( role: reference ))
+
 Use `dose check` instead for a pure shift-total question: how many doses has
 a nurse already given today. That question is about a running count, never
 about whether this particular order is safe to give. Use `consent capture`
 first if the medication order requires patient consent that hasn't been
 recorded yet.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt records whether the dose was given, blocked by an allergy
 conflict, or parked for attending approval, plus the audit entry reference
 for the attempt.
```
