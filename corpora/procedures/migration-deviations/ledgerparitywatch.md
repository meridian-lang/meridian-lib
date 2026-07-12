# Deviation: ledgerparitywatch.meri

- Original: `ledger_parity_watch/SKILL.md`
- Ported: `ledgerparitywatch.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 62 -> 65 (+15 / -12)

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
- L39 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Guarantees`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L52 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 45 non-blank ported lines
- Sections inert total: 4/5 (80% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=6, structure=0, desugar=0, meaning=41

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L39 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Guarantees`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L52 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/ledger_parity_watch/SKILL.md
+++ skills/ledgerparitywatch.meri
@@ -10,14 +10,14 @@
 
 # Ledger Parity Watch
 
-Parity drift is easy to dismiss when it shows up once and expensive to ignore
-when it repeats quietly for a whole day. This skill gives the ledger a running
-parity watch: it evaluates the recent parity history, falls back cleanly when
-that history is too thin to decide, and records the outcome explicitly so the
-operator can inspect which branch fired without reconstructing it from raw
-trace events alone.
+> Parity drift is easy to dismiss when it shows up once and expensive to ignore
+> when it repeats quietly for a whole day. This skill gives the ledger a running
+> parity watch: it evaluates the recent parity history, falls back cleanly when
+> that history is too thin to decide, and records the outcome explicitly so the
+> operator can inspect which branch fired without reconstructing it from raw
+> trace events alone.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a ledger.
 - Output: a parity receipt describing whether the ledger stayed within the
   configured occurrence threshold.
@@ -30,19 +30,22 @@
 - "monitor reconciliation parity"
 
 ## Workflow
+
+### Workflow — steps
+
 let the parity receipt be "parity watch opened".
 if the parity step succeeds in at least 99% of occurrences within the last 30 days,
   Emit: "ledger parity stayed within threshold".
 otherwise,
   Emit: "ledger parity is below threshold or the retained sample is still indeterminate".
-assert the parity step succeeds in at least 99% of occurrences within the last 30 days otherwise:
+assert the parity step succeeds in at least 99% of occurrences within the last 30 days.
+recover from any:
   Emit: "blocking ledger parity assertion failed".
-recover from any:
   Emit: "ledger parity check deferred after the blocking assertion failure".
 proceed, and note "; parity watch pass complete" in the parity receipt.
 Emit: "ledger parity watch pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't reduce a parity watch to the last settle result. A ledger can clear one
   pass and still be drifting over the retained occurrence history.
 - Don't treat the fallback branch as equivalent to "false". The otherwise path
@@ -50,12 +53,12 @@
 - Don't rebuild the text receipt by hand in downstream tooling. The receipt
   binding is part of the workflow so the result stays auditable.
 
-## Guarantees
+## Guarantees (( role: reference ))
 This skill leaves an explicit emitted record for the healthy branch, the K3
 fallback branch, the blocking assertion failure, and the recovery-driven
 deferral so the parity outcome stays inspectable after the run.
 
-## Report shape
+## Report shape (( role: template ))
 The emitted record states whether parity stayed within threshold, whether the
 watch fell back because the retained sample stayed indeterminate or breached the
 threshold, and whether the blocking parity assertion had to recover.
```
