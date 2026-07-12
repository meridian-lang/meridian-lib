# Deviation: accessreviewfreshness.meri

- Original: `access_review_freshness/SKILL.md`
- Ported: `accessreviewfreshness.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 57 -> 60 (+12 / -9)

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
- L33 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Guarantees`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 40 non-blank ported lines
- Sections inert total: 4/5 (80% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=3, structure=0, desugar=0, meaning=39

### Inert section details
- L10 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Guarantees`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/access_review_freshness/SKILL.md
+++ skills/accessreviewfreshness.meri
@@ -10,13 +10,13 @@
 
 # Access Review Freshness
 
-An access review is only useful as evidence while it is still fresh enough to
-say something about the resource in front of you. This skill turns that idea
-into a live control: it asks whether the resource still has review evidence
-inside the retained boundary, and it treats the boundary itself as load-bearing
-so the answer cannot quietly drift away from what the trace policy retains.
+> An access review is only useful as evidence while it is still fresh enough to
+> say something about the resource in front of you. This skill turns that idea
+> into a live control: it asks whether the resource still has review evidence
+> inside the retained boundary, and it treats the boundary itself as load-bearing
+> so the answer cannot quietly drift away from what the trace policy retains.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a resource.
 - Output: a review-freshness verdict at the retention boundary.
 - Side effect: none beyond the emitted review status.
@@ -27,6 +27,9 @@
 - "verify resource review currency"
 
 ## Workflow
+
+### Workflow — steps
+
 if across all runs, the access review step has ever succeeded,
   Emit: "access review freshness found historical review evidence".
 if the resource's status is "active",
@@ -36,7 +39,7 @@
     Emit: "access review freshness found no retained review evidence inside the boundary".
 Emit: "access review freshness pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't stretch a review window past the trace retention and still call the
   answer fresh. Once the evidence is outside retention, this skill no longer
   gets to claim it.
@@ -45,12 +48,12 @@
 - Don't use a cross-run "ever" hit as proof of freshness. Historical evidence
   and still-fresh evidence are separate branches here.
 
-## Guarantees
+## Guarantees (( role: reference ))
 This skill treats the exact 30-day retained boundary as the freshness edge and
 records both the historical-evidence branch and the still-fresh branch
 separately.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt distinguishes historical review evidence from still-fresh review
 evidence and records whether the resource stayed inside the exact retained
 30-day review boundary.
```
