# Deviation: cross_modal_review.meri

- Original: `cross-modal-review/SKILL.md`
- Ported: `cross_modal_review.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 198 -> 193 (+17 / -22)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 13/14 inert (93% inert ratio)
- Judgment: 1 blocks, 5 lines

## Unified diff

```diff
--- original-skills/cross-modal-review/SKILL.md
+++ cross_modal_review.meri
@@ -34,7 +34,7 @@
 > for ad-hoc second opinions; use `gbrain eval cross-modal` for the
 > skillify Phase 3 quality gate. The two are complementary, not redundant.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -45,7 +45,7 @@
 - Refusal from one model triggers a silent switch to the next in chain.
 - The user always makes the final decision (user sovereignty).
 
-## When to invoke (v0.25.1 gating)
+## When to invoke (v0.25.1 gating) (( inert ))
 
 Invoke this skill when:
 
@@ -71,24 +71,19 @@
 
 ## Phases
 
-1. **Capture the work product.** The brain page, analysis, code diff,
-   or decision to be reviewed.
-2. **Load the Contract.** Read the originating skill's Contract section
-   (what was promised).
-3. **Spawn review model.** Send the work + Contract to a different
-   model. Use [conventions/model-routing.md](../conventions/model-routing.md)
-   for model selection.
-4. **Grade.** Model evaluates: did the output follow the Contract?
-   Pass / fail with specific citations.
-5. **Report.** Present agreement / disagreement to the user. Never
-   auto-apply the reviewer's suggestions.
+use judgment to run a cross-modal review of the work product:
+  Capture the brain page, analysis, code diff, or decision to be reviewed.
+  Load the originating skill's Contract section to see what was promised.
+  Spawn a different review model and send it the work plus the Contract.
+  Grade whether the output followed the Contract, pass or fail, with specific citations.
+  Report agreement or disagreement to the user, never auto-applying the reviewer's suggestions.
 
-## Code-review handoff (v0.25.1 extension)
+## Code-review handoff (v0.25.1 extension) (( inert ))
 
 For diff review specifically, gstack ships a `/codex` skill that wraps
 the OpenAI Codex CLI. Two modes:
 
-### Codex Review
+### Codex Review (( inert ))
 
 Independent diff review from a different AI system. The user invokes
 `/codex review` (gstack-shipped); cross-modal-review's job is to
@@ -116,7 +111,7 @@
 User decides what to act on. Cross-model agreement is signal, not
 permission.
 
-### Adversarial Challenge
+### Adversarial Challenge (( inert ))
 
 Same shape, different prompt. Used on security-sensitive changes:
 the reviewer is asked to find injection vectors, race conditions,
@@ -125,7 +120,7 @@
 Output adds an exploitability rating (CRITICAL / HIGH / MEDIUM / LOW)
 and recommended mitigations.
 
-## Refusal routing
+## Refusal routing (( inert ))
 
 If the primary review model refuses:
 
@@ -137,7 +132,7 @@
 
 ## Output format
 
-### Standard review
+### Standard review (( inert ))
 
 ```
 Cross-Modal Review
@@ -152,7 +147,7 @@
 Agreement with primary: {X}%
 ```
 
-### Code review
+### Code review (( inert ))
 
 ```
 Cross-Modal Review (code)
@@ -164,7 +159,7 @@
 {mode-specific output above}
 ```
 
-## User-sovereignty rule (Iron Law)
+## User-sovereignty rule (Iron Law) (( inert ))
 
 Reviewer findings are INFORMATIONAL until the user explicitly approves
 each one. Do NOT incorporate reviewer recommendations into the work
@@ -173,7 +168,7 @@
 is a strong signal — present it as such — but the user makes the
 decision.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Auto-applying reviewer suggestions without user approval
 - ❌ Showing model refusals to the user
@@ -182,7 +177,7 @@
 - ❌ Code-reviewing trivial changes (typos, formatting)
 - ❌ Running code review without git-diff context
 
-## Related skills
+## Related skills (( inert ))
 
 - gstack `/codex` — the actual Codex CLI wrapper this skill hands off
   to for diff-review mode. Cross-modal-review knows WHEN to invoke;
```
