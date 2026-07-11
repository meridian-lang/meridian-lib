# Deviation: rollbackdeploy.meri

- Original: `rollback_deploy/SKILL.md`
- Ported: `rollbackdeploy.meri`
- Tier: 2 (light edits)
- Similarity: 72%
- Lines: 50 -> 56 (+18 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L34 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L45 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/5 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=35

### Inert section details
- L17 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L45 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/rollback_deploy/SKILL.md
+++ skills/rollbackdeploy.meri
@@ -9,31 +9,37 @@
 
 # Rollback Deploy
 
-Rolling back a bad deploy is disruptive enough that it shouldn't happen
-without a human saying yes first — but once approved, it shouldn't stop at
-a single attempt either, because a rollback can itself fail to fully
-restore health on the first try. This skill gates on approval, then loops
-the rollback until the deploy's health genuinely recovers, and if a
-rollback attempt itself fails outright, it holds for manual escalation
-rather than retrying blindly forever.
+> Rolling back a bad deploy is disruptive enough that it shouldn't happen
+> without a human saying yes first — but once approved, it shouldn't stop at
+> a single attempt either, because a rollback can itself fail to fully
+> restore health on the first try. This skill gates on approval, then loops
+> the rollback until the deploy's health genuinely recovers, and if a
+> rollback attempt itself fails outright, it holds for manual escalation
+> rather than retrying blindly forever.
 
 ## When to invoke
 - "roll back unhealthy deploys"
 - "revert failed deploy"
 - "run the deploy rollback pass"
 
-## Workflow
+## Workflow (( role: reference ))
+  until it is not the case that the deploy is unhealthy,
+    roll back the deploy.
+
+### Workflow — steps
+
 fetch unhealthy deploys.
 Check: any unhealthy deploys.
 for each deploy:
   wait for approval of the deploy from an oncall engineer.
-  until it is not the case that the deploy is unhealthy,
-    roll back the deploy.
+
+### Workflow — steps 2
+
     recover from deploy.failed:
       Note: "rollback failed, escalating manually".
 Post: "deploy rollback pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't skip the approval wait for a deploy that "obviously needs" a
   rollback. The approval gate exists so a rollback is a deliberate call,
   not an automatic reflex to any unhealthy reading.
@@ -44,7 +50,7 @@
 ## Guarantees
 make sure no deploys whose status is "failed".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt confirms every unhealthy deploy either recovered after
 rollback or was escalated manually because the rollback itself failed.
 
```
