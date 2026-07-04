# Deviation: cross_modal_review.meri

- Original: `cross-modal-review/SKILL.md`
- Ported: `cross_modal_review.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 198 -> 198 (+14 / -14)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 14/14 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=10, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L15 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L26 `When to invoke (v0.25.1 gating)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L50 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L64 `Code-review handoff (v0.25.1 extension)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L69 `Codex Review`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L97 `Adversarial Challenge`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L106 `Refusal routing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L116 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L118 `Standard review`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L133 `Code review`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L145 `User-sovereignty rule (Iron Law)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L154 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L163 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L173 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/cross-modal-review/SKILL.md
+++ skills/cross_modal_review.meri
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
 
@@ -69,7 +69,7 @@
 - Routine cron output or heartbeat operations
 - Git commit / push of already-reviewed work
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Capture the work product.** The brain page, analysis, code diff,
    or decision to be reviewed.
@@ -83,12 +83,12 @@
 5. **Report.** Present agreement / disagreement to the user. Never
    auto-apply the reviewer's suggestions.
 
-## Code-review handoff (v0.25.1 extension)
+## Code-review handoff (v0.25.1 extension) (( inert ))
 
 For diff review specifically, gstack ships a `/codex` skill that wraps
 the OpenAI Codex CLI. Two modes:
 
-### Codex Review
+### Codex Review (( inert ))
 
 Independent diff review from a different AI system. The user invokes
 `/codex review` (gstack-shipped); cross-modal-review's job is to
@@ -116,7 +116,7 @@
 User decides what to act on. Cross-model agreement is signal, not
 permission.
 
-### Adversarial Challenge
+### Adversarial Challenge (( inert ))
 
 Same shape, different prompt. Used on security-sensitive changes:
 the reviewer is asked to find injection vectors, race conditions,
@@ -125,7 +125,7 @@
 Output adds an exploitability rating (CRITICAL / HIGH / MEDIUM / LOW)
 and recommended mitigations.
 
-## Refusal routing
+## Refusal routing (( inert ))
 
 If the primary review model refuses:
 
@@ -135,9 +135,9 @@
 3. Don't announce the switch.
 4. If ALL models in the chain refuse, escalate to the user.
 
-## Output format
+## Output format (( inert, role: template ))
 
-### Standard review
+### Standard review (( inert ))
 
 ```
 Cross-Modal Review
@@ -152,7 +152,7 @@
 Agreement with primary: {X}%
 ```
 
-### Code review
+### Code review (( inert ))
 
 ```
 Cross-Modal Review (code)
@@ -164,7 +164,7 @@
 {mode-specific output above}
 ```
 
-## User-sovereignty rule (Iron Law)
+## User-sovereignty rule (Iron Law) (( inert ))
 
 Reviewer findings are INFORMATIONAL until the user explicitly approves
 each one. Do NOT incorporate reviewer recommendations into the work
@@ -173,7 +173,7 @@
 is a strong signal — present it as such — but the user makes the
 decision.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Auto-applying reviewer suggestions without user approval
 - ❌ Showing model refusals to the user
@@ -182,7 +182,7 @@
 - ❌ Code-reviewing trivial changes (typos, formatting)
 - ❌ Running code review without git-diff context
 
-## Related skills
+## Related skills (( inert ))
 
 - gstack `/codex` — the actual Codex CLI wrapper this skill hands off
   to for diff-review mode. Cross-modal-review knows WHEN to invoke;
@@ -192,7 +192,7 @@
 - `skills/conventions/cross-modal.yaml` — review pairs + refusal routing
 
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
