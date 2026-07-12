# Deviation: paymentfailuremonitor.meri

- Original: `payment_failure_monitor/SKILL.md`
- Ported: `paymentfailuremonitor.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 58 -> 64 (+18 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L37 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Guarantees`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L51 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 42 non-blank ported lines
- Sections inert total: 4/6 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=42

### Inert section details
- L19 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L37 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Guarantees`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L51 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/payment_failure_monitor/SKILL.md
+++ skills/paymentfailuremonitor.meri
@@ -10,12 +10,12 @@
 
 # Payment Failure Monitor
 
-Payment trouble rarely arrives as one clean failure. More often it starts as a
-thin run history, then a failure streak, then a whole queue of invoices that
-technically still looks "active" while the collector already knows something is
-wrong. This skill keeps those stages separate: it monitors the overall payment
-success rate, treats streaks as their own signal, and preserves the unknown
-state that flows transitively through a derived invoice-health adjective.
+> Payment trouble rarely arrives as one clean failure. More often it starts as a
+> thin run history, then a failure streak, then a whole queue of invoices that
+> technically still looks "active" while the collector already knows something is
+> wrong. This skill keeps those stages separate: it monitors the overall payment
+> success rate, treats streaks as their own signal, and preserves the unknown
+> state that flows transitively through a derived invoice-health adjective.
 
 ## Contract
 the payment step succeeds in at least 90% of runs within the last 30 days.
@@ -25,9 +25,7 @@
 - "monitor payment failures"
 - "check payment retry health"
 
-## Workflow
-if the payment step has failed 3 times in a row,
-  Publish: "payment failure monitor saw a live payment failure streak".
+## Workflow (( role: reference ))
 if the invoice is unpaid,
   if the payment step succeeds in at least 90% of runs within the last 30 days,
     Publish: "payment failure monitor saw healthy invoice history".
@@ -35,9 +33,17 @@
     Publish: "payment failure monitor lacks enough retained history for the invoice".
   otherwise,
     Publish: "payment failure monitor saw unhealthy invoice history".
+
+### Workflow — steps
+
+if the payment step has failed 3 times in a row,
+  Publish: "payment failure monitor saw a live payment failure streak".
+
+### Workflow — steps 2
+
 Publish: "payment failure monitor pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't use the payment-success monitor to explain away a live streak. A good
   long-run percentage can still coexist with an active short-run failure chain.
 - Don't treat the unknown branch as noise. The derived invoice adjective is
@@ -46,12 +52,12 @@
 - Don't move the monitored assertion's cadence into the skill text. This skill
   relies on the default monitor cadence from the trace configuration.
 
-## Guarantees
+## Guarantees (( role: reference ))
 This skill preserves the live failure streak as its own signal and keeps the
 thin-history case explicit instead of letting the statistical branch quietly
 default to a healthy answer.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt separately records a live payment streak, a healthy derived invoice
 state, an explicit unknown state from thin retained history, and the default
 fallback branch when the invoice history is unhealthy.
```
