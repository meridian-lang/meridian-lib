# Deviation: triagealert.meri

- Original: `triage_alert/SKILL.md`
- Ported: `triagealert.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 50 -> 53 (+12 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L30 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/4 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=36

### Inert section details
- L30 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/triage_alert/SKILL.md
+++ skills/triagealert.meri
@@ -9,13 +9,13 @@
 
 # Triage Alert
 
-A firing alert is a claim, not a verdict — some of them are genuinely
-critical and need a human paged in the next thirty seconds, and some of
-them are noisy signals that deserve a second look before anyone's phone
-buzzes. This skill draws that line mechanically for the clear-cut critical
-case (page immediately, then wait for an acknowledgment) and defers to
-judgment for everything else, weighing the alert's severity against the
-service it fired on rather than applying a blanket rule.
+> A firing alert is a claim, not a verdict — some of them are genuinely
+> critical and need a human paged in the next thirty seconds, and some of
+> them are noisy signals that deserve a second look before anyone's phone
+> buzzes. This skill draws that line mechanically for the clear-cut critical
+> case (page immediately, then wait for an acknowledgment) and defers to
+> judgment for everything else, weighing the alert's severity against the
+> service it fired on rather than applying a blanket rule.
 
 ## When to invoke
 - "triage firing alerts"
@@ -23,6 +23,9 @@
 - "run alert triage"
 
 ## Workflow
+
+### Workflow — steps
+
 fetch firing alerts.
 for each alert:
   if the alert is critical,
@@ -32,7 +35,7 @@
     use judgment to classify the alert and recommend a response, weighing its severity and service name before escalating.
 Post: "alert triage pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't page on-call for every firing alert regardless of severity. Paging
   fatigue from noisy non-critical alerts is exactly what erodes trust in
   the next genuinely critical page.
@@ -43,7 +46,7 @@
 ## Guarantees
 make sure any alerts whose status is "firing".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt separates paged critical alerts from alerts routed to judgment,
 so an on-call engineer reviewing the pass can see which alerts got an
 automatic page versus a reasoned call.
```
