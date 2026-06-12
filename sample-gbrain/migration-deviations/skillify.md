# Deviation: skillify.meri

- Original: `skillify/SKILL.md`
- Ported: `skillify.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 311 -> 311 (+19 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 20/24 inert (83% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/skillify/SKILL.md
+++ skills/skillify.meri
@@ -30,14 +30,14 @@
 > dimension list *before* tests cement behavior. Use `/cross-modal-review`
 > for ad-hoc second opinions; use Phase 3 here when skillifying a feature.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 A feature is "properly skilled" when all 11 checklist items pass. Item 3
 (cross-modal eval) is informational in v1.1.0 — it does not gate the
 skillpack-check audit, but a missing or stale receipt is surfaced so the
 user knows where the gate stands.
 
-## The Checklist
+## The Checklist (( inert ))
 
 ```
 □ 1.  SKILL.md           — skill file with frontmatter + contract + phases
@@ -53,7 +53,7 @@
 □ 11. Brain filing       — if it writes pages, entry in brain/RESOLVER.md
 ```
 
-## Phase 0: Should This Be a Skill?
+## Phase 0: Should This Be a Skill? (( inert, role: procedure ))
 
 Before skillifying, check:
 - Will this be invoked 2+ times? (One-off work ≠ skill)
@@ -72,7 +72,7 @@
 
 ## Phase 2: Write SKILL.md + Code (items 1-2)
 
-### SKILL.md frontmatter template (copy-paste):
+### SKILL.md frontmatter template (copy-paste): (( inert ))
 
 ```yaml
 ---
@@ -97,23 +97,23 @@
 
 ## Phase 3: Cross-Modal Eval (item 3) — THE QUALITY GATE
 
-### Why this comes before tests
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
 
-### Step 3: Run the eval gate
+### Step 3: Run the eval gate (( inert ))
 
 ```bash
 gbrain eval cross-modal \
@@ -151,7 +151,7 @@
 Exit code 2; CI wrappers should treat this as "did not run cleanly", not
 "failed quality gate".
 
-### Step 4: Cycle until you pass (≤3 cycles)
+### Step 4: Cycle until you pass (≤3 cycles) (( inert ))
 
 ```
 CYCLE 1:
@@ -176,7 +176,7 @@
     - Why (e.g., "would require architectural change")
 ```
 
-### Cycles + cost guardrails
+### Cycles + cost guardrails (( inert ))
 
 - Default `--cycles 3` in TTY, `--cycles 1` in non-TTY (limits scripted
   bulk spend in CI loops).
@@ -185,7 +185,7 @@
   estimate as a ceiling for default `--max-tokens 4000`.
 - A `--budget-usd N` hard cap is a v0.27.x follow-up TODO.
 
-### Provider configuration
+### Provider configuration (( inert ))
 
 Models resolve through the gbrain AI gateway. Configure once with:
 
@@ -198,19 +198,19 @@
 `GOOGLE_GENERATIVE_AI_API_KEY`, `TOGETHER_API_KEY`, etc. The gateway reads
 from `~/.gbrain/config.json` plus `process.env`.
 
-### Cost expectations
+### Cost expectations (( inert ))
 
 3 cycles × 3 models = 9 frontier calls max per run. With Opus-class +
 GPT-4o-class + Gemini-1.5-Pro, expect $1–3 per full run on default
 `--max-tokens 4000`. Receipts include the per-call model identifiers so
 you can audit retroactively.
 
-### Skip cross-modal eval when:
+### Skip cross-modal eval when: (( inert ))
 
 - Output is < 200 tokens (trivial — not worth 9 API calls).
 - The skill is a thin wrapper around a single API call (one cycle is enough).
 
-## Phase 4: Tests (items 4-6)
+## Phase 4: Tests (items 4-6) (( inert, role: procedure ))
 
 NOW that eval has proven quality, write tests that lock it in:
 
@@ -218,7 +218,7 @@
 **Integration tests** — hit real endpoints. Catch bugs mocks hide.
 **LLM evals** — quality/correctness for LLM steps. Lighter than cross-modal eval — test specific behaviors.
 
-## Phase 5: Resolver + Check-Resolvable (items 7-9)
+## Phase 5: Resolver + Check-Resolvable (items 7-9) (( inert, role: procedure ))
 
 1. Add to skills/RESOLVER.md with trigger phrases users ACTUALLY type
 2. Resolver eval: feed triggers, assert correct routing
@@ -228,7 +228,7 @@
    - No DRY violations (shared logic in lib/, not copy-pasted)
    - No ambiguous trigger routing
 
-## Phase 6: E2E + Brain Filing (items 10-11)
+## Phase 6: E2E + Brain Filing (items 10-11) (( inert, role: procedure ))
 
 - E2E smoke: full pipeline from trigger to side effect
 - Brain filing: add to brain/RESOLVER.md if the skill writes brain pages
@@ -243,7 +243,7 @@
 gbrain check-resolvable --json | jq .ok          # resolver clean
 ```
 
-## Worked Example: Skillifying a "summarize-pr" Feature
+## Worked Example: Skillifying a "summarize-pr" Feature (( inert ))
 
 ```
 Phase 0: Yes — invoked weekly, 50+ lines, clear trigger "summarize this PR"
@@ -262,7 +262,7 @@
 Phase 7: All green. Score: 11/11
 ```
 
-## Quality Gates
+## Quality Gates (( inert ))
 
 NOT properly skilled until:
 
@@ -296,7 +296,7 @@
 the per-item detail string, so agents can route on the structured envelope
 without parsing prose.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Writing tests before cross-modal eval (locks in mediocrity)
 - ❌ Using budget models for eval (C student grading A student)
```
