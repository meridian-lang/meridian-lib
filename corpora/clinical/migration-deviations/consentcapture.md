# Deviation: consentcapture.meri

- Original: `consent_capture/SKILL.md`
- Ported: `consentcapture.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 54 -> 54 (+9 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `When NOT to use this skill`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/6 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=39

### Inert section details
- L10 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `When NOT to use this skill`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/consent_capture/SKILL.md
+++ skills/consentcapture.meri
@@ -9,13 +9,13 @@
 
 # Consent Capture
 
-A missing consent record is not the same thing as an implied yes, but under
-time pressure it is easy to treat it that way. This skill exists to make
-consent an explicit, recorded step: it asks for consent, and when consent
-isn't granted outright it waits for a real follow-up signal rather than
-assuming the silence resolves itself.
+> A missing consent record is not the same thing as an implied yes, but under
+> time pressure it is easy to treat it that way. This skill exists to make
+> consent an explicit, recorded step: it asks for consent, and when consent
+> isn't granted outright it waits for a real follow-up signal rather than
+> assuming the silence resolves itself.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a patient.
 - Output: either a granted consent record or a parked request waiting on a
   follow-up signal.
@@ -35,20 +35,20 @@
   record consent for the patient.
 Emit: "consent capture pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't proceed with the procedure while consent is still unresolved —
   the follow-up wait exists precisely so a pending consent can't be
   mistaken for a granted one.
 - Don't log a verbal assurance as a granted consent. Only the recorded
   consent call counts.
 
-## When NOT to use this skill
+## When NOT to use this skill (( role: reference ))
 Use `medication administer` on its own for a routine order that doesn't
 carry its own consent requirement — running this skill for every order
 regardless of whether it needs consent just adds a step nobody is
 checking.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt records whether consent was granted immediately or only after
 a follow-up signal, and when the record was made.
 
```
