# Deviation: handoffreliabilitymonitor.meri

- Original: `handoff_reliability_monitor/SKILL.md`
- Ported: `handoffreliabilitymonitor.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 57 -> 67 (+19 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L19 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.
- L43 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 42 non-blank ported lines
- Sections inert total: 3/6 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1, tools-metadata=1
- Judgment: 2 blocks, 2 lines
- canonical_drift: synonym=6, structure=0, desugar=0, meaning=42

### Inert section details
- L19 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.
- L43 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/handoff_reliability_monitor/SKILL.md
+++ skills/handoffreliabilitymonitor.meri
@@ -10,12 +10,12 @@
 
 # Handoff Reliability Monitor
 
-The dangerous handoff is not the loudly broken one. It is the handoff that
-looks routine enough to skip a second thought while one patient detail quietly
-falls out of the chain. This skill monitors handoff reliability as an ongoing
-signal, escalates clearly unmonitored patients deterministically, and leaves
-the genuinely ambiguous follow-up cases to a judgment step whose tool scope is
-kept intentionally narrow.
+> The dangerous handoff is not the loudly broken one. It is the handoff that
+> looks routine enough to skip a second thought while one patient detail quietly
+> falls out of the chain. This skill monitors handoff reliability as an ongoing
+> signal, escalates clearly unmonitored patients deterministically, and leaves
+> the genuinely ambiguous follow-up cases to a judgment step whose tool scope is
+> kept intentionally narrow.
 
 ## Contract
 the handoff step succeeds in at least 90% of runs within the last 30 days, checked every 4 hours.
@@ -25,21 +25,31 @@
 - "check handoff reliability"
 - "monitor shift handoff quality"
 
-## Tools Used
+## Tools Used (( role: tools ))
 - list the active census (`patient.list`)
 - read current vital trends (`vitals.read`)
 
 ## Workflow
+
+### Workflow — steps
+
 1. fetch active patients.
 2. for each patient:
   1. read the vital signs for the patient.
   2. if the patient is unmonitored,
     escalate the patient.
+
+### Workflow — steps 2
+
+use judgment to follow the Workflow — steps 2 guidance:
   3. otherwise,
     use judgment to decide whether the patient needs an extra handoff follow-up based on the latest vital trend and hold status.
+
+### Workflow — steps 3
+
 3. Emit: "handoff reliability monitor pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't treat the monitor as a substitute for the deterministic unmonitored
   escalation. The judgment step is only for the ambiguous follow-up cases.
 - Don't widen the judgment tool scope just because more context would be
@@ -50,7 +60,7 @@
 ## Guarantees
 make sure at most 50 patients.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt records the monitor outcome, every deterministic escalation for an
 unmonitored patient, and any privacy-scoped judgment follow-up decision needed
 for a borderline handoff.
```
