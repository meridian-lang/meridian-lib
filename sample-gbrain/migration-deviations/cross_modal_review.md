# Deviation: cross_modal_review.meri

- Original: `cross-modal-review/SKILL.md`
- Ported: `cross_modal_review.meri`
- Tier: 2 (light edits)
- Similarity: 65%
- Lines: 198 -> 195 (+67 / -70)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 9/14 inert (64% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=7, template=2
- Judgment: 3 blocks, 31 lines

### Inert section details
- L27 `When to invoke (v0.25.1 gating)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L60 `Code-review handoff (v0.25.1 extension)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L93 `Adversarial Challenge`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L112 `Output format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L114 `Standard review`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L129 `Code review`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L141 `User-sovereignty rule (Iron Law)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L160 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L170 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/cross-modal-review/SKILL.md
+++ skills/cross_modal_review.meri
@@ -34,18 +34,19 @@
 > for ad-hoc second opinions; use `gbrain eval cross-modal` for the
 > skillify Phase 3 quality gate. The two are complementary, not redundant.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
+> This skill guarantees:
 
-- Work product is reviewed by a different model before finalizing.
-- The review is graded against the originating skill's Contract section
+!!! checklist (( ai-autonomy ))
+- [ ] Work product is reviewed by a different model before finalizing.
+- [ ] The review is graded against the originating skill's Contract section
   (what was promised), not vibes.
-- Agreement and disagreement are reported transparently.
-- Refusal from one model triggers a silent switch to the next in chain.
-- The user always makes the final decision (user sovereignty).
+- [ ] Agreement and disagreement are reported transparently.
+- [ ] Refusal from one model triggers a silent switch to the next in chain.
+- [ ] The user always makes the final decision (user sovereignty).
 
-## When to invoke (v0.25.1 gating)
+## When to invoke (v0.25.1 gating) (( inert ))
 
 Invoke this skill when:
 
@@ -71,73 +72,68 @@
 
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
+### Codex Review (( role: procedure ))
 
-Independent diff review from a different AI system. The user invokes
-`/codex review` (gstack-shipped); cross-modal-review's job is to
-RECOGNIZE when this is the right tool and recommend it explicitly.
-
-**When to recommend `/codex review`:**
-- After a substantive diff lands and before merge
-- When the user wants a second opinion that's NOT another Claude
-
-**Output framing (when cross-modal-review surfaces Codex output):**
-
-```
-CODEX REVIEW (independent second opinion):
-══════════════════════════════════════════
-<full codex output, verbatim>
-══════════════════════════════════════════
-
-CROSS-MODEL ANALYSIS:
-  Both found:    [overlapping findings]
-  Only Codex:    [findings unique to Codex]
-  Only Claude:   [findings unique to my analysis]
-  Agreement:     X% (N/M findings overlap)
-```
-
-User decides what to act on. Cross-model agreement is signal, not
-permission.
-
-### Adversarial Challenge
-
+use judgment to follow the Codex Review guidance:
+  Independent diff review from a different AI system. The user invokes
+  `/codex review` (gstack-shipped); cross-modal-review's job is to
+  RECOGNIZE when this is the right tool and recommend it explicitly.
+  
+  **When to recommend `/codex review`:**
+  item: After a substantive diff lands and before merge
+  item: When the user wants a second opinion that's NOT another Claude
+  
+  **Output framing (when cross-modal-review surfaces Codex output):**
+  
+  ```
+  CODEX REVIEW (independent second opinion):
+  ══════════════════════════════════════════
+  <full codex output, verbatim>
+  ══════════════════════════════════════════
+  
+  CROSS-MODEL ANALYSIS:
+    Both found:    [overlapping findings]
+    Only Codex:    [findings unique to Codex]
+    Only Claude:   [findings unique to my analysis]
+    Agreement:     X% (N/M findings overlap)
+  ```
+  
+  User decides what to act on. Cross-model agreement is signal, not
+  permission.
+### Adversarial Challenge (( inert ))
+  
 Same shape, different prompt. Used on security-sensitive changes:
 the reviewer is asked to find injection vectors, race conditions,
 auth bypasses, data leaks, privilege escalation paths.
-
+  
 Output adds an exploitability rating (CRITICAL / HIGH / MEDIUM / LOW)
 and recommended mitigations.
 
-## Refusal routing
+## Refusal routing (( role: procedure ))
 
-If the primary review model refuses:
-
-1. Switch silently to the next model in the chain (see
-   `conventions/cross-modal.yaml`).
-2. Don't show the refusal to the user.
-3. Don't announce the switch.
-4. If ALL models in the chain refuse, escalate to the user.
-
+use judgment to follow the Refusal routing guidance:
+  If the primary review model refuses:
+  
+  1. Switch silently to the next model in the chain (see
+     `conventions/cross-modal.yaml`).
+  2. Don't show the refusal to the user.
+  3. Don't announce the switch.
+  4. If ALL models in the chain refuse, escalate to the user.
 ## Output format
 
-### Standard review
+### Standard review (( inert ))
 
 ```
 Cross-Modal Review
@@ -152,7 +148,7 @@
 Agreement with primary: {X}%
 ```
 
-### Code review
+### Code review (( inert ))
 
 ```
 Cross-Modal Review (code)
@@ -164,7 +160,7 @@
 {mode-specific output above}
 ```
 
-## User-sovereignty rule (Iron Law)
+## User-sovereignty rule (Iron Law) (( inert ))
 
 Reviewer findings are INFORMATIONAL until the user explicitly approves
 each one. Do NOT incorporate reviewer recommendations into the work
@@ -173,16 +169,17 @@
 is a strong signal — present it as such — but the user makes the
 decision.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- ❌ Auto-applying reviewer suggestions without user approval
-- ❌ Showing model refusals to the user
-- ❌ Using the same model for review and generation
-- ❌ Skipping the Contract reference (reviewing vibes, not guarantees)
-- ❌ Code-reviewing trivial changes (typos, formatting)
-- ❌ Running code review without git-diff context
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Auto-applying reviewer suggestions without user approval
+- [ ] ❌ Showing model refusals to the user
+- [ ] ❌ Using the same model for review and generation
+- [ ] ❌ Skipping the Contract reference (reviewing vibes, not guarantees)
+- [ ] ❌ Code-reviewing trivial changes (typos, formatting)
+- [ ] ❌ Running code review without git-diff context
 
-## Related skills
+## Related skills (( inert ))
 
 - gstack `/codex` — the actual Codex CLI wrapper this skill hands off
   to for diff-review mode. Cross-modal-review knows WHEN to invoke;
```
