# Deviation: skillify.meri

- Original: `skillify/SKILL.md`
- Ported: `skillify.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 311 -> 341 (+70 / -40)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L19 `The Checklist`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L87 `Why this comes before tests`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L92 `Step 1: Pick a representative input`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L98 `Step 2: Run the skill, capture output`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L149 `Step 4: Cycle until you pass (≤3 cycles)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L212 `Skip cross-modal eval when:`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L252 `Worked Example: Skillifying a "summarize-pr" Feature`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L285 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 10/23 (43% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=9, template=1
- Judgment: 11 blocks, 0 lines

### Inert section details
- L19 `The Checklist`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L87 `Why this comes before tests`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L92 `Step 1: Pick a representative input`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L98 `Step 2: Run the skill, capture output`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L149 `Step 4: Cycle until you pass (≤3 cycles)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L174 `Cycles + cost guardrails`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L186 `Provider configuration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L212 `Skip cross-modal eval when:`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L252 `Worked Example: Skillifying a "summarize-pr" Feature`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L285 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/skillify/SKILL.md
+++ skills/skillify.meri
@@ -30,14 +30,15 @@
 > dimension list *before* tests cement behavior. Use `/cross-modal-review`
 > for ad-hoc second opinions; use Phase 3 here when skillifying a feature.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 A feature is "properly skilled" when all 11 checklist items pass. Item 3
 (cross-modal eval) is informational in v1.1.0 — it does not gate the
 skillpack-check audit, but a missing or stale receipt is surfaced so the
 user knows where the gate stands.
 
-## The Checklist
+## The Checklist (( inert ))
 
 ```
 □ 1.  SKILL.md           — skill file with frontmatter + contract + phases
@@ -54,6 +55,7 @@
 ```
 
 ## Phase 0: Should This Be a Skill?
+use judgment to follow the Phase 0: Should This Be a Skill? guidance:
 
 Before skillifying, check:
 - Will this be invoked 2+ times? (One-off work ≠ skill)
@@ -63,6 +65,7 @@
 If no to all three, it's a script, not a skill. Move on.
 
 ## Phase 1: Audit
+use judgment to follow the Phase 1: Audit guidance:
 
 ```
 Feature: [name]
@@ -71,8 +74,10 @@
 ```
 
 ## Phase 2: Write SKILL.md + Code (items 1-2)
+use judgment to follow the Phase 2: Write SKILL.md + Code (items 1-2) guidance:
 
 ### SKILL.md frontmatter template (copy-paste):
+use judgment to follow the SKILL.md frontmatter template (copy-paste): guidance:
 
 ```yaml
 ---
@@ -93,27 +98,49 @@
 
 Body must include: **Contract** (what it guarantees), **Phases** (step-by-step), **Output Format** (what it produces).
 
+
+#### SKILL.md frontmatter template (copy-paste): — steps
+
 Extract deterministic code into `scripts/*.ts`.
 
 ## Phase 3: Cross-Modal Eval (item 3) — THE QUALITY GATE
-
-### Why this comes before tests
+use judgment to follow the Phase 3: Cross-Modal Eval (item 3) — THE QUALITY GATE guidance:
+
+### Why this comes before tests (( inert ))
 
 Tests lock in behavior. If the behavior is mediocre, tests lock in mediocrity.
 Cross-modal eval proves the quality bar FIRST, then tests cement it.
 
-### Step 1: Pick a representative input
+### Step 1: Pick a representative input (( inert ))
 
 Choose the input that exercises the skill's hardest documented use case. If
 unsure: use the primary trigger example from SKILL.md, or the most complex
 real-world input from the last 7 days of memory files.
 
-### Step 2: Run the skill, capture output
+### Step 2: Run the skill, capture output (( inert ))
 
 Run the skill on the representative input. The OUTPUT FILE is what gets
 evaluated.
 
 ### Step 3: Run the eval gate
+use judgment to follow the Step 3: Run the eval gate guidance:
+
+**These MUST be frontier models from DIFFERENT providers.** Using a single
+provider's family or budget models defeats the purpose — different families
+have less correlated blind spots. Refresh the list when a new model
+generation ships.
+
+**Pass criteria (BOTH must be true):**
+
+1. Every dimension's mean across successful models ≥ 7.
+2. No single model scored any dimension < 5 (the floor).
+
+Receipt is still written (forensics) but the gate is not authoritative.
+Exit code 2; CI wrappers should treat this as "did not run cleanly", not
+"failed quality gate".
+
+
+#### Step 3: Run the eval gate — steps
 
 ```bash
 gbrain eval cross-modal \
@@ -127,31 +154,21 @@
 sha-8 binds the receipt to the current SKILL.md content — re-running after
 edits writes a new receipt).
 
-**Default models** (override per slot via `--slot-a-model`, `--slot-b-model`,
-`--slot-c-model`):
-
+> **Default models** (override per slot via `--slot-a-model`, `--slot-b-model`,
+> `--slot-c-model`):
+
+!!! table (( ai-discretion ))
 | Slot | Default | Provider |
 |------|---------|----------|
 | A | `openai:gpt-4o` | OpenAI |
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
+#### Step 3: Run the eval gate — steps 2
+
+Inconclusive: fewer than 2 of 3 models returned parseable scores.
+### Step 4: Cycle until you pass (≤3 cycles) (( inert ))
 
 ```
 CYCLE 1:
@@ -176,41 +193,51 @@
     - Why (e.g., "would require architectural change")
 ```
 
-### Cycles + cost guardrails
+### Cycles + cost guardrails (( inert ))
 
 - Default `--cycles 3` in TTY, `--cycles 1` in non-TTY (limits scripted
   bulk spend in CI loops).
+
+#### Cycles + cost guardrails — steps
+
 - The command prints an estimated max-cost-per-cycle from a small pricing
   constant before each run. Real cost varies with prompt size; treat the
   estimate as a ceiling for default `--max-tokens 4000`.
 - A `--budget-usd N` hard cap is a v0.27.x follow-up TODO.
 
-### Provider configuration
-
-Models resolve through the gbrain AI gateway. Configure once with:
+### Provider configuration (( inert ))
+
+Or set env vars: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`,
+`GOOGLE_GENERATIVE_AI_API_KEY`, `TOGETHER_API_KEY`, etc. The gateway reads
+from `~/.gbrain/config.json` plus `process.env`.
+
+
+#### Provider configuration — steps
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
-### Cost expectations
+### Cost expectations (( inert ))
+
+
+#### Cost expectations — steps
 
 3 cycles × 3 models = 9 frontier calls max per run. With Opus-class +
 GPT-4o-class + Gemini-1.5-Pro, expect $1–3 per full run on default
 `--max-tokens 4000`. Receipts include the per-call model identifiers so
 you can audit retroactively.
 
-### Skip cross-modal eval when:
+### Skip cross-modal eval when: (( inert ))
 
 - Output is < 200 tokens (trivial — not worth 9 API calls).
 - The skill is a thin wrapper around a single API call (one cycle is enough).
 
 ## Phase 4: Tests (items 4-6)
+use judgment to follow the Phase 4: Tests (items 4-6) guidance:
 
 NOW that eval has proven quality, write tests that lock it in:
 
@@ -219,6 +246,7 @@
 **LLM evals** — quality/correctness for LLM steps. Lighter than cross-modal eval — test specific behaviors.
 
 ## Phase 5: Resolver + Check-Resolvable (items 7-9)
+use judgment to follow the Phase 5: Resolver + Check-Resolvable (items 7-9) guidance:
 
 1. Add to skills/RESOLVER.md with trigger phrases users ACTUALLY type
 2. Resolver eval: feed triggers, assert correct routing
@@ -243,7 +271,7 @@
 gbrain check-resolvable --json | jq .ok          # resolver clean
 ```
 
-## Worked Example: Skillifying a "summarize-pr" Feature
+## Worked Example: Skillifying a "summarize-pr" Feature (( inert ))
 
 ```
 Phase 0: Yes — invoked weekly, 50+ lines, clear trigger "summarize this PR"
@@ -263,6 +291,7 @@
 ```
 
 ## Quality Gates
+use judgment to follow the Quality Gates guidance:
 
 NOT properly skilled until:
 
@@ -275,7 +304,7 @@
 - Check-resolvable shows no orphans, overlaps, or DRY violations.
 - Brain filing if applicable.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Skillify produces three durable artifacts per skill:
 
@@ -288,15 +317,16 @@
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
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Writing tests before cross-modal eval (locks in mediocrity)
 - ❌ Using budget models for eval (C student grading A student)
```
