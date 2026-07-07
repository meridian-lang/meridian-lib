# Deviation: shifthandoff.meri

- Original: `shift_handoff/SKILL.md`
- Ported: `shifthandoff.meri`
- Tier: 2 (light edits)
- Similarity: 69%
- Lines: 62 -> 71 (+25 / -16)

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
- L43 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L61 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/6 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L22 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L61 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/shift_handoff/SKILL.md
+++ skills/shifthandoff.meri
@@ -8,14 +8,14 @@
 
 # Shift Handoff
 
-A shift change is exactly the moment a quiet problem gets lost — the
-outgoing team knows what's held and why, and that context doesn't
-transfer just because the incoming team can see the same chart system.
-This skill exists to force the transfer explicitly: it counts the active
-census, counts how many patients are currently held, and renders both
-into one receipt the incoming team reads before touching a single chart.
+> A shift change is exactly the moment a quiet problem gets lost — the
+> outgoing team knows what's held and why, and that context doesn't
+> transfer just because the incoming team can see the same chart system.
+> This skill exists to force the transfer explicitly: it counts the active
+> census, counts how many patients are currently held, and renders both
+> into one receipt the incoming team reads before touching a single chart.
 
-## Contract
+## Contract (( role: reference ))
 - Input: none — this skill reads the full active census itself.
 - Output: a rendered handoff summary naming the active count and the held
   count.
@@ -26,22 +26,28 @@
 - "run shift handoff"
 - "render shift handoff report"
 
-## Workflow
-fetch active patients.
-Check: at least 1 patient.
-Check: at most 50 patients.
-let patient count be the number of patients.
-let held count be the number of patients whose status is "held".
+## Workflow (( role: reference ))
 bind handoff report =
   ```
   handoff-summary:
   active patients: {{ patient count }}
   held for review: {{ held count }}
   ```
-Emit: handoff report.
 Post: "shift handoff pass complete".
 
-## Anti-Patterns
+
+### Workflow — steps
+
+fetch active patients.
+Check: at least 1 patient.
+Check: at most 50 patients.
+let patient count be the number of patients.
+let held count be the number of patients whose status is "held".
+
+### Workflow — steps 2
+
+Emit: handoff report.
+## Anti-Patterns (( role: reference ))
 - Don't skip the handoff on the assumption that the outgoing shift
   mentioned everything verbally. A verbal note doesn't survive a second
   handoff down the line; the rendered receipt does.
@@ -50,13 +56,16 @@
   more.
 
 ## When NOT to use this skill
+
+### When NOT to use this skill — steps (( role: reference ))
+
 Use `discharge review` for the actual discharge decision on a specific
 held patient. This skill stops at the count.
 
 ## Guarantees
 make sure at most 50 patients whose status is "held".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states the active census size and how many of those patients
 are currently held, in one line each.
 
```
