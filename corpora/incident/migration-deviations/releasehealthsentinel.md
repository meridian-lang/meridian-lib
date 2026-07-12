# Deviation: releasehealthsentinel.meri

- Original: `release_health_sentinel/SKILL.md`
- Ported: `releasehealthsentinel.meri`
- Tier: 2 (light edits)
- Similarity: 74%
- Lines: 73 -> 82 (+25 / -16)

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
- L53 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L63 `Guarantees`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 58 non-blank ported lines
- Sections inert total: 5/6 (83% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=4, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=57

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L63 `Guarantees`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/release_health_sentinel/SKILL.md
+++ skills/releasehealthsentinel.meri
@@ -10,14 +10,14 @@
 
 # Release Health Sentinel
 
-Release health is where a raw event list stops being useful on its own. A
-single old failure does not mean the service is unsafe today, but a fresh
-cluster, a live streak, or a missing successful anchor can each mean very
-different things operationally. This skill exists to keep those cases
-separate, surface them explicitly, and refuse to flatten "unknown" into
-"healthy enough" when the history has no last successful deploy to anchor on.
+> Release health is where a raw event list stops being useful on its own. A
+> single old failure does not mean the service is unsafe today, but a fresh
+> cluster, a live streak, or a missing successful anchor can each mean very
+> different things operationally. This skill exists to keep those cases
+> separate, surface them explicitly, and refuse to flatten "unknown" into
+> "healthy enough" when the history has no last successful deploy to anchor on.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a service.
 - Output: a release-health verdict that preserves historical, recent, streak,
   and anchorless-since distinctions.
@@ -29,7 +29,14 @@
 - "check release health"
 - "inspect deploy failure history"
 
-## Workflow
+## Workflow (( role: reference ))
+if the service is recovered since the last deploy step succeeded,
+  Post: "release health is healthy since the last successful deploy".
+otherwise,
+  Post: "release health is not healthy since the last successful deploy".
+
+### Workflow — steps
+
 if the deploy step has ever failed,
   Post: "release health saw a prior deploy failure".
 if the deploy step has failed within the last 7 days,
@@ -40,17 +47,19 @@
   Post: "release health saw an active deploy failure streak".
 if across all runs, the deploy step has ever failed,
   Post: "release health saw a cross-run deploy failure".
-if the service is healthy since the last deploy step succeeded,
-  Post: "release health is healthy since the last successful deploy".
+
+### Workflow — steps 2
+
 if it is unknown whether:
   Post: "release health has no successful deploy anchor yet".
-otherwise,
-  Post: "release health is not healthy since the last successful deploy".
-assert the service is healthy since the last deploy step succeeded otherwise:
+
+### Workflow — steps 3
+
+assert the service is recovered since the last deploy step succeeded otherwise:
   Post: "release health blocking guard fell back because the service is unhealthy or the deploy history has no successful anchor".
 Post: "release health sentinel pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't treat "ever failed" as interchangeable with "failed within the last 7
   days". Those are different release stories, and this skill keeps both on
   purpose.
@@ -60,12 +69,12 @@
 - Don't treat an anchorless `since the last` check as if it were false. If no
   successful deploy exists yet, the answer is unknown and the workflow says so.
 
-## Guarantees
+## Guarantees (( role: reference ))
 This skill records each temporal contrast explicitly and preserves the
 anchorless `since the last` case as its own witnessed fallback, rather than
 silently flattening it into a healthy or unhealthy result.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt distinguishes five release-health signals in plain language:
 historical failure, recent-window failure, repeated recent failure, live
 failure streak, and since-the-last health with an explicit unknown/default
```
