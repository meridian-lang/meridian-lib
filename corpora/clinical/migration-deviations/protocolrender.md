# Deviation: protocolrender.meri

- Original: `protocol_render/SKILL.md`
- Ported: `protocolrender.meri`
- Tier: 2 (light edits)
- Similarity: 68%
- Lines: 69 -> 79 (+29 / -19)

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
- L68 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/7 (57% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=52

### Inert section details
- L12 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L28 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/protocol_render/SKILL.md
+++ skills/protocolrender.meri
@@ -9,15 +9,15 @@
 
 # Protocol Render
 
-Treatment protocols get revised often enough that a clinician reaching for
-one from memory is taking a real risk — bundle versions drift, and a
-tier that was safe two revisions ago might not be the current guidance.
-This skill exists to make the lookup itself the source of truth: it finds
-the protocol covering the medication, checks the medication's risk level
-against a fixed dosing-tier table, and renders both together in one
-receipt so nobody has to reconcile two separate references by hand.
+> Treatment protocols get revised often enough that a clinician reaching for
+> one from memory is taking a real risk — bundle versions drift, and a
+> tier that was safe two revisions ago might not be the current guidance.
+> This skill exists to make the lookup itself the source of truth: it finds
+> the protocol covering the medication, checks the medication's risk level
+> against a fixed dosing-tier table, and renders both together in one
+> receipt so nobody has to reconcile two separate references by hand.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a medication.
 - Output: a rendered protocol summary naming the protocol, its version,
   and the medication's dosing tier.
@@ -33,11 +33,7 @@
 | high | 1 |
 | low | 4 |
 
-## Workflow
-look up the protocol for the medication.
-let protocol name be the protocol's name.
-let protocol version be the protocol's version.
-bind max doses = the max doses per day corresponding to the risk level "high" in the table.
+## Workflow (( role: reference ))
 bind protocol summary =
   ```
   protocol-summary:
@@ -45,17 +41,31 @@
   version: {{ protocol version }}
   max doses per day: {{ max doses }}
   ```
-Emit: protocol summary.
 Post: "protocol render pass complete".
 
-## Anti-Patterns
-- Don't quote a dosing tier from memory instead of running this lookup —
-  the whole point of the render is that the table, not a clinician's
-  recollection, is the current source.
+
+### Workflow — steps
+
+look up the protocol for the medication.
+let protocol name be the protocol's name.
+let protocol version be the protocol's version.
+bind max doses = the max doses per day corresponding to the risk level "high" in the table.
+
+### Workflow — steps 2
+
+Emit: protocol summary.
+## Anti-Patterns (( role: reference ))
 - Don't skip rendering the version number alongside the tier. A tier
   without its version is not verifiable against anything.
 
+
+### Anti-Patterns — steps
+
+- Don't quote a dosing tier from memory instead of running this lookup — the whole point of the render is that the table, not a clinician's recollection, is the current source.
 ## When NOT to use this skill
+
+### When NOT to use this skill — steps (( role: reference ))
+
 Use `medication administer` when the protocol lookup is just one step
 inside actually giving a dose — this skill is the standalone reference
 render, not a step embedded in an administration pass.
@@ -63,7 +73,7 @@
 ## Guarantees
 every emitted protocol summary contains "protocol-summary".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt names the protocol, its version, and the dosing tier the
 medication's risk level maps to.
 
```
