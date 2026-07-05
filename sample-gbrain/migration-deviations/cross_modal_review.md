# Deviation: cross_modal_review.meri

- Original: `cross-modal-review/SKILL.md`
- Ported: `cross_modal_review.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 198 -> 233 (+58 / -23)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L123 `Adversarial Challenge`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L150 `Standard review`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L165 `Code review`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L177 `User-sovereignty rule (Iron Law)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L186 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L208 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 11/11 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=10, template=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L15 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `When to invoke (v0.25.1 gating)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L59 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L88 `Codex Review`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L123 `Adversarial Challenge`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L132 `Refusal routing`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L150 `Standard review`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L165 `Code review`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L177 `User-sovereignty rule (Iron Law)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L186 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L208 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/cross-modal-review/SKILL.md
+++ skills/cross_modal_review.meri
@@ -34,18 +34,24 @@
 > for ad-hoc second opinions; use `gbrain eval cross-modal` for the
 > skillify Phase 3 quality gate. The two are complementary, not redundant.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
 - Work product is reviewed by a different model before finalizing.
+- Agreement and disagreement are reported transparently.
+- Refusal from one model triggers a silent switch to the next in chain.
+
+### Contract — steps (( role: reference ))
+
 - The review is graded against the originating skill's Contract section
   (what was promised), not vibes.
-- Agreement and disagreement are reported transparently.
-- Refusal from one model triggers a silent switch to the next in chain.
+
+### Contract — steps 2 (( role: reference ))
+
 - The user always makes the final decision (user sovereignty).
 
-## When to invoke (v0.25.1 gating)
+## When to invoke (v0.25.1 gating) (( role: reference ))
 
 Invoke this skill when:
 
@@ -59,9 +65,6 @@
   or bulk writes (see [conventions/test-before-bulk.md](../conventions/test-before-bulk.md)).
 - **Skill creation / modification** — new or rewritten skills that
   affect operational behavior.
-- **Brain-page quality concerns** — when brain writes need validation
-  against the originating skill's Contract.
-
 Do NOT invoke for:
 
 - Simple memory writes or brain-page updates
@@ -69,7 +72,13 @@
 - Routine cron output or heartbeat operations
 - Git commit / push of already-reviewed work
 
-## Phases
+
+### When to invoke (v0.25.1 gating) — steps
+
+- Brain-page quality concerns — when brain writes need validation
+  against the originating skill's Contract.
+
+## Phases (( role: reference ))
 
 1. **Capture the work product.** The brain page, analysis, code diff,
    or decision to be reviewed.
@@ -78,23 +87,32 @@
 3. **Spawn review model.** Send the work + Contract to a different
    model. Use [conventions/model-routing.md](../conventions/model-routing.md)
    for model selection.
+   Pass / fail with specific citations.
+
+### Phases — steps
+
+use judgment to follow the Phases — steps guidance:
 4. **Grade.** Model evaluates: did the output follow the Contract?
-   Pass / fail with specific citations.
-5. **Report.** Present agreement / disagreement to the user. Never
+
+### Phases — steps 2
+
+5. Present agreement / disagreement to the user. Never
    auto-apply the reviewer's suggestions.
 
 ## Code-review handoff (v0.25.1 extension)
+
+
+### Code-review handoff (v0.25.1 extension) — steps
 
 For diff review specifically, gstack ships a `/codex` skill that wraps
 the OpenAI Codex CLI. Two modes:
 
-### Codex Review
+### Codex Review (( role: reference ))
 
 Independent diff review from a different AI system. The user invokes
 `/codex review` (gstack-shipped); cross-modal-review's job is to
 RECOGNIZE when this is the right tool and recommend it explicitly.
 
-**When to recommend `/codex review`:**
 - After a substantive diff lands and before merge
 - When the user wants a second opinion that's NOT another Claude
 
@@ -113,10 +131,18 @@
   Agreement:     X% (N/M findings overlap)
 ```
 
+
+### Codex Review — steps
+
+When to recommend `/codex review`:
+
+### Codex Review — steps 2
+
+use judgment to follow the Codex Review — steps 2 guidance:
 User decides what to act on. Cross-model agreement is signal, not
 permission.
 
-### Adversarial Challenge
+### Adversarial Challenge (( role: reference ))
 
 Same shape, different prompt. Used on security-sensitive changes:
 the reviewer is asked to find injection vectors, race conditions,
@@ -125,19 +151,25 @@
 Output adds an exploitability rating (CRITICAL / HIGH / MEDIUM / LOW)
 and recommended mitigations.
 
-## Refusal routing
+## Refusal routing (( role: reference ))
+
+2. Don't show the refusal to the user.
+3. Don't announce the switch.
+
+### Refusal routing — steps
 
 If the primary review model refuses:
 
 1. Switch silently to the next model in the chain (see
    `conventions/cross-modal.yaml`).
-2. Don't show the refusal to the user.
-3. Don't announce the switch.
+
+### Refusal routing — steps 2
+
 4. If ALL models in the chain refuse, escalate to the user.
 
-## Output format
-
-### Standard review
+## Output format (( role: template ))
+
+### Standard review (( role: reference ))
 
 ```
 Cross-Modal Review
@@ -152,7 +184,7 @@
 Agreement with primary: {X}%
 ```
 
-### Code review
+### Code review (( role: reference ))
 
 ```
 Cross-Modal Review (code)
@@ -164,7 +196,7 @@
 {mode-specific output above}
 ```
 
-## User-sovereignty rule (Iron Law)
+## User-sovereignty rule (Iron Law) (( role: reference ))
 
 Reviewer findings are INFORMATIONAL until the user explicitly approves
 each one. Do NOT incorporate reviewer recommendations into the work
@@ -173,7 +205,7 @@
 is a strong signal — present it as such — but the user makes the
 decision.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Auto-applying reviewer suggestions without user approval
 - ❌ Showing model refusals to the user
@@ -184,6 +216,9 @@
 
 ## Related skills
 
+
+### Related skills — steps
+
 - gstack `/codex` — the actual Codex CLI wrapper this skill hands off
   to for diff-review mode. Cross-modal-review knows WHEN to invoke;
   /codex knows HOW.
@@ -192,7 +227,7 @@
 - `skills/conventions/cross-modal.yaml` — review pairs + refusal routing
 
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
