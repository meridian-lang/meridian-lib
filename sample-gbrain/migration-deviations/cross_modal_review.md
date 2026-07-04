# Deviation: cross_modal_review.meri

- Original: `cross-modal-review/SKILL.md`
- Ported: `cross_modal_review.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 198 -> 212 (+31 / -17)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L104 `Adversarial Challenge`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L128 `Standard review`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L143 `Code review`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L155 `User-sovereignty rule (Iron Law)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L187 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 6/11 (55% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=5, template=1
- Judgment: 5 blocks, 0 lines

### Inert section details
- L104 `Adversarial Challenge`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L113 `Refusal routing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L128 `Standard review`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L143 `Code review`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L155 `User-sovereignty rule (Iron Law)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L187 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/cross-modal-review/SKILL.md
+++ skills/cross_modal_review.meri
@@ -34,7 +34,8 @@
 > for ad-hoc second opinions; use `gbrain eval cross-modal` for the
 > skillify Phase 3 quality gate. The two are complementary, not redundant.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -46,6 +47,7 @@
 - The user always makes the final decision (user sovereignty).
 
 ## When to invoke (v0.25.1 gating)
+use judgment to follow the When to invoke (v0.25.1 gating) guidance:
 
 Invoke this skill when:
 
@@ -70,6 +72,7 @@
 - Git commit / push of already-reviewed work
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 1. **Capture the work product.** The brain page, analysis, code diff,
    or decision to be reviewed.
@@ -83,12 +86,16 @@
 5. **Report.** Present agreement / disagreement to the user. Never
    auto-apply the reviewer's suggestions.
 
-## Code-review handoff (v0.25.1 extension)
+## Code-review handoff (v0.25.1 extension) (( inert ))
+
+
+### Code-review handoff (v0.25.1 extension) — steps
 
 For diff review specifically, gstack ships a `/codex` skill that wraps
 the OpenAI Codex CLI. Two modes:
 
 ### Codex Review
+use judgment to follow the Codex Review guidance:
 
 Independent diff review from a different AI system. The user invokes
 `/codex review` (gstack-shipped); cross-modal-review's job is to
@@ -116,7 +123,7 @@
 User decides what to act on. Cross-model agreement is signal, not
 permission.
 
-### Adversarial Challenge
+### Adversarial Challenge (( inert ))
 
 Same shape, different prompt. Used on security-sensitive changes:
 the reviewer is asked to find injection vectors, race conditions,
@@ -125,19 +132,22 @@
 Output adds an exploitability rating (CRITICAL / HIGH / MEDIUM / LOW)
 and recommended mitigations.
 
-## Refusal routing
-
-If the primary review model refuses:
-
-1. Switch silently to the next model in the chain (see
-   `conventions/cross-modal.yaml`).
+## Refusal routing (( inert ))
+
 2. Don't show the refusal to the user.
 3. Don't announce the switch.
 4. If ALL models in the chain refuse, escalate to the user.
 
-## Output format
-
-### Standard review
+
+### Refusal routing — steps
+
+> If the primary review model refuses:
+
+1. Switch silently to the next model in the chain (see
+   `conventions/cross-modal.yaml`).
+## Output format (( inert, role: template ))
+
+### Standard review (( inert ))
 
 ```
 Cross-Modal Review
@@ -152,7 +162,7 @@
 Agreement with primary: {X}%
 ```
 
-### Code review
+### Code review (( inert ))
 
 ```
 Cross-Modal Review (code)
@@ -164,7 +174,7 @@
 {mode-specific output above}
 ```
 
-## User-sovereignty rule (Iron Law)
+## User-sovereignty rule (Iron Law) (( inert ))
 
 Reviewer findings are INFORMATIONAL until the user explicitly approves
 each one. Do NOT incorporate reviewer recommendations into the work
@@ -173,7 +183,8 @@
 is a strong signal — present it as such — but the user makes the
 decision.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Auto-applying reviewer suggestions without user approval
 - ❌ Showing model refusals to the user
@@ -182,7 +193,10 @@
 - ❌ Code-reviewing trivial changes (typos, formatting)
 - ❌ Running code review without git-diff context
 
-## Related skills
+## Related skills (( inert, role: procedure ))
+
+
+### Related skills — steps
 
 - gstack `/codex` — the actual Codex CLI wrapper this skill hands off
   to for diff-review mode. Cross-modal-review knows WHEN to invoke;
@@ -192,7 +206,7 @@
 - `skills/conventions/cross-modal.yaml` — review pairs + refusal routing
 
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
