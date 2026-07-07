# Deviation: healthchecksweep.meri

- Original: `healthcheck_sweep/SKILL.md`
- Ported: `healthchecksweep.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 51 -> 51 (+9 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L29 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L40 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L29 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L40 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/healthcheck_sweep/SKILL.md
+++ skills/healthchecksweep.meri
@@ -9,13 +9,13 @@
 
 # Healthcheck Sweep
 
-Health checks and runbook lookups don't depend on each other, so making one
-wait for the other is wasted latency. This skill fetches every service and
-every runbook, confirms each service is properly named before doing
-anything else, and then runs the health checks and the runbook refresh at
-the same time — the health sweep in the foreground, the runbook lookup in
-the background — before closing with a check that nothing came back
-degraded.
+> Health checks and runbook lookups don't depend on each other, so making one
+> wait for the other is wasted latency. This skill fetches every service and
+> every runbook, confirms each service is properly named before doing
+> anything else, and then runs the health checks and the runbook refresh at
+> the same time — the health sweep in the foreground, the runbook lookup in
+> the background — before closing with a check that nothing came back
+> degraded.
 
 ## When to invoke
 - "sweep service health"
@@ -34,7 +34,7 @@
 Check: no services whose status is "degraded".
 Post: "healthcheck sweep complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't run the runbook lookups sequentially after the health checks "to
   keep things simple." The two are independent; running them
   simultaneously is what keeps this sweep fast enough to run frequently.
@@ -45,7 +45,7 @@
 ## Guarantees
 make sure all services have a name.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt confirms every service is healthy and named, and that the
 runbook refresh completed alongside the sweep rather than after it.
 
```
