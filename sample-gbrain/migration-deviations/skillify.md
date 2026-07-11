# Deviation: skillify.meri

- Original: `skillify/SKILL.md`
- Ported: `skillify.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 311 -> 338 (+85 / -58)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L11 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L18 `The Checklist`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Phase 0: Should This Be a Skill?`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Phase 1: Audit`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L81 `Why this comes before tests`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L86 `Step 1: Pick a representative input`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L92 `Step 2: Run the skill, capture output`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L144 `Step 4: Cycle until you pass (≤3 cycles)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L207 `Skip cross-modal eval when:`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L212 `Phase 4: Tests (items 4-6)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L220 `Phase 5: Resolver + Check-Resolvable (items 7-9)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L230 `Phase 6: E2E + Brain Filing (items 10-11)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L245 `Worked Example: Skillifying a "summarize-pr" Feature`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L280 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 20/21 (95% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=19, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=235

### Inert section details
- L11 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L18 `The Checklist`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Phase 0: Should This Be a Skill?`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Phase 1: Audit`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `SKILL.md frontmatter template (copy-paste):`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L81 `Why this comes before tests`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L86 `Step 1: Pick a representative input`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L92 `Step 2: Run the skill, capture output`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L97 `Step 3: Run the eval gate`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L144 `Step 4: Cycle until you pass (≤3 cycles)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L169 `Cycles + cost guardrails`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L181 `Provider configuration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L207 `Skip cross-modal eval when:`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L212 `Phase 4: Tests (items 4-6)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L220 `Phase 5: Resolver + Check-Resolvable (items 7-9)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L230 `Phase 6: E2E + Brain Filing (items 10-11)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L245 `Worked Example: Skillifying a "summarize-pr" Feature`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L264 `Quality Gates`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L280 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L301 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/skillify/SKILL.md
+++ skills/skillify.meri
@@ -30,14 +30,14 @@
 > dimension list *before* tests cement behavior. Use `/cross-modal-review`
 > for ad-hoc second opinions; use Phase 3 here when skillifying a feature.
 
-## Contract
+## Contract (( role: reference ))
 
 A feature is "properly skilled" when all 11 checklist items pass. Item 3
 (cross-modal eval) is informational in v1.1.0 — it does not gate the
 skillpack-check audit, but a missing or stale receipt is surfaced so the
 user knows where the gate stands.
 
-## The Checklist
+## The Checklist (( role: reference ))
 
 ```
 □ 1.  SKILL.md           — skill file with frontmatter + contract + phases
@@ -53,7 +53,7 @@
 □ 11. Brain filing       — if it writes pages, entry in brain/RESOLVER.md
 ```
 
-## Phase 0: Should This Be a Skill?
+## Phase 0: Should This Be a Skill? (( role: reference ))
 
 Before skillifying, check:
 - Will this be invoked 2+ times? (One-off work ≠ skill)
@@ -62,7 +62,7 @@
 
 If no to all three, it's a script, not a skill. Move on.
 
-## Phase 1: Audit
+## Phase 1: Audit (( role: reference ))
 
 ```
 Feature: [name]
@@ -72,7 +72,7 @@
 
 ## Phase 2: Write SKILL.md + Code (items 1-2)
 
-### SKILL.md frontmatter template (copy-paste):
+### SKILL.md frontmatter template (copy-paste): (( role: reference ))
 
 ```yaml
 ---
@@ -91,29 +91,47 @@
 ---
 ```
 
-Body must include: **Contract** (what it guarantees), **Phases** (step-by-step), **Output Format** (what it produces).
+
+### SKILL.md frontmatter template (copy-paste): — steps (( role: reference ))
+
+Body must include: Contract (what it guarantees), Phases (step-by-step), Output Format (what it produces).
 
 Extract deterministic code into `scripts/*.ts`.
 
 ## Phase 3: Cross-Modal Eval (item 3) — THE QUALITY GATE
 
-### Why this comes before tests
+### Why this comes before tests (( role: reference ))
 
 Tests lock in behavior. If the behavior is mediocre, tests lock in mediocrity.
 Cross-modal eval proves the quality bar FIRST, then tests cement it.
 
-### Step 1: Pick a representative input
+### Step 1: Pick a representative input (( role: reference ))
 
 Choose the input that exercises the skill's hardest documented use case. If
 unsure: use the primary trigger example from SKILL.md, or the most complex
 real-world input from the last 7 days of memory files.
 
-### Step 2: Run the skill, capture output
+### Step 2: Run the skill, capture output (( role: reference ))
 
 Run the skill on the representative input. The OUTPUT FILE is what gets
 evaluated.
 
-### Step 3: Run the eval gate
+### Step 3: Run the eval gate (( role: reference ))
+
+**These MUST be frontier models from DIFFERENT providers.** Using a single
+provider's family or budget models defeats the purpose — different families
+have less correlated blind spots. Refresh the list when a new model
+generation ships.
+
+1. Every dimension's mean across successful models ≥ 7.
+2. No single model scored any dimension < 5 (the floor).
+
+Receipt is still written (forensics) but the gate is not authoritative.
+Exit code 2; CI wrappers should treat this as "did not run cleanly", not
+"failed quality gate".
+
+
+### Step 3: Run the eval gate — steps (( role: reference ))
 
 ```bash
 gbrain eval cross-modal \
@@ -127,8 +145,8 @@
 sha-8 binds the receipt to the current SKILL.md content — re-running after
 edits writes a new receipt).
 
-**Default models** (override per slot via `--slot-a-model`, `--slot-b-model`,
-`--slot-c-model`):
+> **Default models** (override per slot via `--slot-a-model`, `--slot-b-model`,
+> `--slot-c-model`):
 
 | Slot | Default | Provider |
 |------|---------|----------|
@@ -136,22 +154,16 @@
 | B | `anthropic:claude-opus-4-7` | Anthropic |
 | C | `google:gemini-1.5-pro` | Google |
 
-**These MUST be frontier models from DIFFERENT providers.** Using a single
-provider's family or budget models defeats the purpose — different families
-have less correlated blind spots. Refresh the list when a new model
-generation ships.
-
-**Pass criteria (BOTH must be true):**
-
-1. Every dimension's mean across successful models ≥ 7.
-2. No single model scored any dimension < 5 (the floor).
-
-**Inconclusive:** fewer than 2 of 3 models returned parseable scores.
-Receipt is still written (forensics) but the gate is not authoritative.
-Exit code 2; CI wrappers should treat this as "did not run cleanly", not
-"failed quality gate".
-
-### Step 4: Cycle until you pass (≤3 cycles)
+
+### Step 3: Run the eval gate — steps 2 (( role: reference ))
+
+Pass criteria (BOTH must be true):
+
+
+### Step 3: Run the eval gate — steps 3 (( role: reference ))
+
+Inconclusive: fewer than 2 of 3 models returned parseable scores.
+### Step 4: Cycle until you pass (≤3 cycles) (( role: reference ))
 
 ```
 CYCLE 1:
@@ -176,49 +188,58 @@
     - Why (e.g., "would require architectural change")
 ```
 
-### Cycles + cost guardrails
+### Cycles + cost guardrails (( role: reference ))
 
 - Default `--cycles 3` in TTY, `--cycles 1` in non-TTY (limits scripted
   bulk spend in CI loops).
+
+### Cycles + cost guardrails — steps (( role: reference ))
+
 - The command prints an estimated max-cost-per-cycle from a small pricing
   constant before each run. Real cost varies with prompt size; treat the
   estimate as a ceiling for default `--max-tokens 4000`.
 - A `--budget-usd N` hard cap is a v0.27.x follow-up TODO.
 
-### Provider configuration
-
-Models resolve through the gbrain AI gateway. Configure once with:
+### Provider configuration (( role: reference ))
+
+Or set env vars: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
+`GOOGLE_GENERATIVE_AI_API_KEY`, `TOGETHER_API_KEY`, etc. The gateway reads
+from `~/.gbrain/config.json` plus `process.env`.
+
+
+### Provider configuration — steps
+
+> Models resolve through the gbrain AI gateway. Configure once with:
 
 ```bash
 gbrain providers test    # see what's configured
 gbrain config            # set keys
 ```
 
-Or set env vars: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
-`GOOGLE_GENERATIVE_AI_API_KEY`, `TOGETHER_API_KEY`, etc. The gateway reads
-from `~/.gbrain/config.json` plus `process.env`.
-
 ### Cost expectations
+
+
+### Cost expectations — steps (( role: reference ))
 
 3 cycles × 3 models = 9 frontier calls max per run. With Opus-class +
 GPT-4o-class + Gemini-1.5-Pro, expect $1–3 per full run on default
 `--max-tokens 4000`. Receipts include the per-call model identifiers so
 you can audit retroactively.
 
-### Skip cross-modal eval when:
+### Skip cross-modal eval when: (( role: reference ))
 
 - Output is < 200 tokens (trivial — not worth 9 API calls).
 - The skill is a thin wrapper around a single API call (one cycle is enough).
 
-## Phase 4: Tests (items 4-6)
+## Phase 4: Tests (items 4-6) (( role: reference ))
 
 NOW that eval has proven quality, write tests that lock it in:
 
-**Unit tests** — every branch of deterministic logic. Mock external calls.
-**Integration tests** — hit real endpoints. Catch bugs mocks hide.
-**LLM evals** — quality/correctness for LLM steps. Lighter than cross-modal eval — test specific behaviors.
-
-## Phase 5: Resolver + Check-Resolvable (items 7-9)
+Unit tests — every branch of deterministic logic. Mock external calls.
+Integration tests — hit real endpoints. Catch bugs mocks hide.
+LLM evals — quality/correctness for LLM steps. Lighter than cross-modal eval — test specific behaviors.
+
+## Phase 5: Resolver + Check-Resolvable (items 7-9) (( role: reference ))
 
 1. Add to skills/RESOLVER.md with trigger phrases users ACTUALLY type
 2. Resolver eval: feed triggers, assert correct routing
@@ -228,7 +249,7 @@
    - No DRY violations (shared logic in lib/, not copy-pasted)
    - No ambiguous trigger routing
 
-## Phase 6: E2E + Brain Filing (items 10-11)
+## Phase 6: E2E + Brain Filing (items 10-11) (( role: reference ))
 
 - E2E smoke: full pipeline from trigger to side effect
 - Brain filing: add to brain/RESOLVER.md if the skill writes brain pages
@@ -243,7 +264,7 @@
 gbrain check-resolvable --json | jq .ok          # resolver clean
 ```
 
-## Worked Example: Skillifying a "summarize-pr" Feature
+## Worked Example: Skillifying a "summarize-pr" Feature (( role: reference ))
 
 ```
 Phase 0: Yes — invoked weekly, 50+ lines, clear trigger "summarize this PR"
@@ -262,20 +283,23 @@
 Phase 7: All green. Score: 11/11
 ```
 
-## Quality Gates
-
-NOT properly skilled until:
+## Quality Gates (( role: reference ))
+
+- All tests pass (unit + integration + LLM evals).
+- Resolver entry exists with real trigger phrases.
+- Check-resolvable shows no orphans, overlaps, or DRY violations.
+- Brain filing if applicable.
+
+
+### Quality Gates — steps (( role: reference ))
+
+> NOT properly skilled until:
 
 - All required items pass (1-2, 4-10; 11 only when applicable).
 - Cross-modal eval (item 3) has a current receipt OR is explicitly waived
   with rationale (item 3 is informational; not blocking, but a missing
   receipt is visible in the audit).
-- All tests pass (unit + integration + LLM evals).
-- Resolver entry exists with real trigger phrases.
-- Check-resolvable shows no orphans, overlaps, or DRY violations.
-- Brain filing if applicable.
-
-## Output Format
+## Output Format (( role: template ))
 
 Skillify produces three durable artifacts per skill:
 
@@ -288,15 +312,15 @@
    receipt to the current `SKILL.md` content. `gbrain skillify check`
    surfaces the status (`found` / `stale` / `missing`) as informational.
 3. **An audit verdict** from `gbrain skillify check`: `properly skilled` |
-   `close — create: <missing items>` | `needs skillify — run /skillify on
-   <target>`. Score is `<passed>/<total>`. Required items gate the verdict;
+   `close — create: <missing items>` | ``needs skillify — run /skillify on
+   <target>`. Score is `<passed>/<total>``. Required items gate the verdict;
    item 11 (cross-modal eval) is informational and never blocks PASS.
 
 JSON output (`gbrain skillify check --json`) includes the same fields plus
 the per-item detail string, so agents can route on the structured envelope
 without parsing prose.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Writing tests before cross-modal eval (locks in mediocrity)
 - ❌ Using budget models for eval (C student grading A student)
@@ -305,7 +329,10 @@
 - ❌ Eval without fix cycle (vanity metrics)
 - ❌ Code with no SKILL.md (invisible to resolver)
 - ❌ Tests that reimplement production code (masks real bugs)
-- ❌ Resolver entry with internal jargon (must mirror real user language)
 - ❌ Two skills doing the same thing (merge or kill one)
 - ❌ Running cross-modal eval on trivial outputs (< 200 tokens, not worth 9 API calls)
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+- ❌ Resolver entry with internal jargon (must mirror real user language)
```
