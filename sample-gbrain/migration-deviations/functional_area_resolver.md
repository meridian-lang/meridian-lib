# Deviation: functional_area_resolver.meri

- Original: `functional-area-resolver/SKILL.md`
- Ported: `functional_area_resolver.meri`
- Tier: 2 (light edits)
- Similarity: 68%
- Lines: 354 -> 414 (+154 / -94)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Problem`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L10 `Solution: Functional-Area Dispatchers`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L15 `Before (270 rows, 25KB)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L27 `After (13 rows, 13KB)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `A/B Eval Results`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L86 `What the data shows`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L179 `Step 2: When to compress which file`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L334 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L338 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 18/18 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=17, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Problem`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L10 `Solution: Functional-Area Dispatchers`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L15 `Before (270 rows, 25KB)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L27 `After (13 rows, 13KB)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L36 `Why It Works`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L49 `A/B Eval Results`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L86 `What the data shows`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L112 `Methodology caveats`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L133 `Prior work and citations`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L179 `Step 2: When to compress which file`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L193 `Step 3: Identify functional areas`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L215 `Step 4: Build the area entry format`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L241 `Step 6 (MANDATORY): Verify routing accuracy`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L320 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L334 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L338 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L353 `Maintenance`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L371 `v1.0.0 — 2026-05-11`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/functional-area-resolver/SKILL.md
+++ skills/functional_area_resolver.meri
@@ -36,18 +36,18 @@
 
 # Functional-Area Resolver — Pattern for Compressing Routing Tables
 
-## Problem
+## Problem (( role: reference ))
 
 Routing files (RESOLVER.md, AGENTS.md) grow as skills are added. Each skill
 gets its own row (trigger -> skill path). At ~200+ skills this hits 25-30KB,
 eating context budget that should go to actual work.
 
-## Solution: Functional-Area Dispatchers
+## Solution: Functional-Area Dispatchers (( role: reference ))
 
 Replace N rows per area with **one entry per functional area**. Each entry
 lists all sub-skills it can dispatch to in a `(dispatcher for: ...)` clause.
 
-### Before (270 rows, 25KB)
+### Before (270 rows, 25KB) (( role: reference ))
 ```
 - Creating/enriching a person or company page -> `enrich`
 - Fix broken citations in brain pages -> `citation-fixer`
@@ -59,7 +59,7 @@
 ...
 ```
 
-### After (13 rows, 13KB)
+### After (13 rows, 13KB) (( role: reference ))
 ```
 - **Brain & knowledge**: create/enrich/search/export brain pages, filing,
   citations, publishing, book analysis, strategic reading, concept synthesis,
@@ -68,17 +68,20 @@
   strategic-reading, concept-synthesis, archive-crawler, ...)
 ```
 
-## Why It Works
+## Why It Works (( role: reference ))
 
 The LLM doesn't need one row per sub-skill. It needs:
 1. **Area recognition** — "this is about brain pages" -> Brain & Knowledge
-2. **Sub-skill visibility** — the `(dispatcher for: ...)` list shows what's available
 3. **The skill file itself** — once the LLM reads `brain-ops/SKILL.md`, it has full routing detail
 
 This is a **two-layer dispatch**: routing file routes to the area, the area
 skill routes to the specific sub-skill. Each layer does one job well.
 
-## A/B Eval Results
+
+### Why It Works — steps
+
+2. Sub-skill visibility — the `(dispatcher for: ...)` list shows what's available
+## A/B Eval Results (( role: reference ))
 
 Three resolver architectures tested across three Anthropic frontier models
 (Opus 4.7, Sonnet 4.6, Haiku 4.5) on real production AGENTS.md content,
@@ -95,21 +98,27 @@
 
 ### Training corpus (n=20, 3 seeds × 3 variants × 3 models, LENIENT)
 
+
+### Training corpus (n=20, 3 seeds × 3 variants × 3 models, LENIENT) — steps (( role: reference ))
+
 | Variant | Opus 4.7 | Sonnet 4.6 | Haiku 4.5 | Size |
 |---|---|---|---|---|
 | baseline (270 bullet rows) | 81.7% ± 7.2% | 86.7% ± 7.2% | 73.3% ± 7.2% | 25KB |
-| **functional-areas** (this pattern) | **98.3% ± 7.2%** | **100% ± 0%** | **88.3% ± 7.2%** | **13KB** |
+| functional-areas (this pattern) | 98.3% ± 7.2% | 100% ± 0% | 88.3% ± 7.2% | 13KB |
 | resolver-of-resolvers (no dispatcher clause) | 63.3% ± 14.3% | 41.7% ± 7.2% | 65.0% ± 12.4% | 10KB |
 
 ### Held-out blind corpus (n=5, 3 seeds, LENIENT)
+
+
+### Held-out blind corpus (n=5, 3 seeds, LENIENT) — steps (( role: reference ))
 
 | Variant | Opus 4.7 | Sonnet 4.6 | Haiku 4.5 |
 |---|---|---|---|
 | baseline | 100% ± 0% | 100% ± 0% | 100% ± 0% |
-| **functional-areas** | **100% ± 0%** | **100% ± 0%** | **100% ± 0%** |
-| resolver-of-resolvers | 100% ± 0% | **73.3% ± 28.7%** | 100% ± 0% |
-
-### What the data shows
+| functional-areas | 100% ± 0% | 100% ± 0% | 100% ± 0% |
+| resolver-of-resolvers | 100% ± 0% | 73.3% ± 28.7% | 100% ± 0% |
+
+### What the data shows (( role: reference ))
 
 1. **Functional-areas BEATS baseline on training across all three models** (+13 to +17pp) at 48% the size. Held-out is saturated at 100% for both — within margin of error.
 
@@ -120,6 +129,9 @@
 4. **The pattern's value scales with model tier.** Compression gain (functional-areas vs baseline, training, LENIENT) is +17pp on Opus, +13pp on Sonnet, +15pp on Haiku. Sonnet shows the cleanest separation between functional-areas and resolver-of-resolvers (100% vs 41.7%) — model capacity affects how much the dispatcher signal matters.
 
 ### Reproduce
+
+
+### Reproduce — steps
 
 ```bash
 cd evals/functional-area-resolver
@@ -129,19 +141,16 @@
 node rescore.mjs baseline-runs/2026-05-11-opus-4-7.jsonl  # zero-cost re-score
 ```
 
-Receipts (model, prompt_template_hash, fixtures_hash, harness_sha, ts):
+> Receipts (model, prompt_template_hash, fixtures_hash, harness_sha, ts):
 `evals/functional-area-resolver/baseline-runs/2026-05-11-{opus-4-7,sonnet-4-6,haiku-4-5}.jsonl`.
 
-### Methodology caveats
+### Methodology caveats (( role: reference ))
 
 - **Production prompt matters.** With a naive "return the skill slug" prompt
   (no instruction about `(dispatcher for: ...)`), every compression variant
   collapses to ~30-60% on Opus. The dispatcher-aware prompt is in
   `evals/functional-area-resolver/harness-runner.ts:PROMPT_TEMPLATE`. Use it
   as the template for your agent's harness; without it, compression breaks.
-- **Training corpus and variants were authored by the same release.** Held-out
-  corpus was written before the variants and never adjusted; this mitigates
-  but does not eliminate overfitting.
 - **Confidence intervals via t-distribution across n=3 seeded repeats.** Hold the
   n=3 lower-bound: high CIs mean the underlying sample is noisy.
 - **Single-vendor result.** All three models are Anthropic. Cross-vendor
@@ -150,35 +159,50 @@
   the harness can't distinguish between "100%" and "95% with one nondeterministic
   miss." Expanding to ≥20 is a v0.33.x follow-up.
 
-### Prior work and citations
-
-The pattern is a **static-prompt analog of hierarchical agent routing**, a
-2024-2025 research direction:
-
-- **AnyTool** ([arXiv:2402.04253](https://arxiv.org/abs/2402.04253)) showed
-  meta-agent → category-agent → tool-agent hierarchy on 16K APIs beats flat
-  retrieval by +35.4pp. The `(dispatcher for: ...)` clause is the
-  meta-agent's view collapsed into a single LLM pass.
+
+### Methodology caveats — steps (( role: reference ))
+
+- Held-out
+  corpus was written before the variants and never adjusted; this mitigates
+  but does not eliminate overfitting.
+### Prior work and citations (( role: reference ))
+
 - **RAG-MCP** ([arXiv:2505.03275](https://arxiv.org/html/2505.03275v1))
   reports 49.2% prompt-token reduction at 3.2× accuracy gain via
   embedding-based pre-retrieval. The token-reduction story matches ours
   (48% smaller), via a different mechanism (RAG vs static dispatcher).
-- **Anthropic Agent Skills**
-  ([engineering blog](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills))
+
+### Prior work and citations — steps (( role: reference ))
+
+> The pattern is a **static-prompt analog of hierarchical agent routing**, a
+> 2024-2025 research direction:
+
+- AnyTool (arXiv:2402.04253) showed
+  meta-agent → category-agent → tool-agent hierarchy on 16K APIs beats flat
+  retrieval by +35.4pp. The `(dispatcher for: ...)` clause is the
+  meta-agent's view collapsed into a single LLM pass.
+
+### Prior work and citations — steps 2 (( role: reference ))
+
+- Anthropic Agent Skills
+  (engineering blog)
   promotes progressive disclosure: frontmatter (~80 tokens) always loaded,
   SKILL.md body loaded on match. This skill applies the same principle at
   the routing-table level, not the per-skill body level.
 
-The 2025-2026 literature has no published benchmark for **static-prompt
-hierarchical routing** (every published hierarchical scheme resolves the
+The 2025-2026 literature has no published benchmark for static-prompt
+hierarchical routing (every published hierarchical scheme resolves the
 hierarchy at runtime via a second LLM call). Our finding — that the
 hierarchy can be inlined into a single-LLM-pass dispatcher list and retain
 routing accuracy — is the open contribution. See
 `evals/functional-area-resolver/README.md` for methodology details.
 
-## How To Compress
+## How To Compress (( role: reference ))
 
 ### Step 1: Preconditions
+
+
+### Step 1: Preconditions — steps (( role: reference ))
 
 Refuse to compress if either gate fails:
 - Source routing file is under 12KB (compression overhead exceeds benefit).
@@ -187,7 +211,7 @@
 
 If a user wants to override either gate, they ask explicitly with `--force`.
 
-### Step 2: When to compress which file
+### Step 2: When to compress which file (( role: reference ))
 
 GBrain workspaces often have TWO routing files merged at runtime (per
 `src/core/check-resolvable.ts` v0.31.7): `skills/RESOLVER.md` and a sibling
@@ -201,15 +225,11 @@
 If the deployment uses only one routing file, this section is a no-op —
 compress that one.
 
-### Step 3: Identify functional areas
-
-Group skills by domain. Typical areas (adjust per deployment):
-
-- **Brain & Knowledge** — brain-ops as dispatcher
+### Step 3: Identify functional areas (( role: reference ))
+
 - **Content Ingestion** — ingest as dispatcher
 - **Calendar & Scheduling** — google-calendar as dispatcher
 - **Email & Comms** — executive-assistant as dispatcher
-- **Research & Investigation** — perplexity-research as dispatcher
 - **X/Twitter & Social** — x-ingest as dispatcher
 - **Places & Travel** — checkin as dispatcher
 - **Product & Building** — acp-coding as dispatcher
@@ -217,7 +237,17 @@
 - **Tasks & Logistics** — daily-task-manager as dispatcher
 - **People & Contacts** — google-contacts as dispatcher
 
-### Step 4: Build the area entry format
+
+### Step 3: Identify functional areas — steps
+
+> Group skills by domain. Typical areas (adjust per deployment):
+
+- Brain & Knowledge — brain-ops as dispatcher
+
+### Step 3: Identify functional areas — steps 2
+
+- Research & Investigation — perplexity-research as dispatcher
+### Step 4: Build the area entry format (( role: reference ))
 
 Each area entry follows this template:
 
@@ -229,50 +259,27 @@
 Rules:
 - Trigger phrases should be broad enough to catch intent ("brain pages, enrich,
   search, filing, citations, book analysis")
+- The dispatcher skill file should have its own internal routing table
+
+
+### Step 4: Build the area entry format — steps (( role: reference ))
+
 - Sub-skill list should be comprehensive — this is how the LLM knows what's available
-- The dispatcher skill file should have its own internal routing table
-
 ### Step 5: Keep always-on entries separate
+
+
+### Step 5: Keep always-on entries separate — steps (( role: reference ))
 
 Gates and always-on entries (acknowledge, multi-user, entity-detector, etc.)
 stay as individual rows — they're checked on every message, not dispatched.
 
-### Step 6 (MANDATORY): Verify routing accuracy
+### Step 6 (MANDATORY): Verify routing accuracy (( role: reference ))
 
 Run two gates before committing the compressed file. Do NOT commit if either
 fails.
 
-**Gate 1: Structural verification.** Confirms your `routing-eval.jsonl`
-fixtures still resolve to the right skills under the compressed routing file.
-Run from the workspace whose routing file you just edited:
-
-```bash
-gbrain routing-eval --json
-```
-
 If accuracy on your fixtures drops below 95%, revert and tune the area
 entries before re-running.
-
-**Gate 2: LLM A/B verification on YOUR edited file.** Confirms a frontier
-LLM can still drill into the dispatcher list and reach sub-skills under
-your specific compression. Requires a gbrain repo checkout because the
-harness lives there. Copy your edited routing file into the harness's
-variants directory, then invoke the harness with `--variants` pointing
-at it:
-
-```bash
-# In your agent workspace, identify the routing file you just compressed.
-EDITED=/path/to/your/AGENTS.md       # or skills/RESOLVER.md, whichever you edited
-
-# In your gbrain repo checkout:
-cd /path/to/gbrain/evals/functional-area-resolver
-TMP=$(mktemp -d)/variants && mkdir -p "$TMP"
-cp "$EDITED" "$TMP/my-edit.md"
-
-# Run the harness against your file (sequential, ~75 calls × $0.0076 ≈ $0.57 on Opus).
-ANTHROPIC_API_KEY=... node harness.mjs --variants-dir "$TMP" --variants my-edit \
-                                       --model opus --parallel 3 --yes
-```
 
 The harness uses gbrain's bundled fixture set, so this verifies "did the LLM
 land in the right sub-skill for routing intents the gbrain-bundled fixtures
@@ -281,9 +288,6 @@
 `fixtures.jsonl` + `fixtures-held-out.jsonl` setup with intents specific
 to your skills.
 
-If the lenient (same-area) score on your variant drops below 95%, revert the
-compression and tune. Common causes:
-- A sub-skill was omitted from the `(dispatcher for: ...)` list.
 - Trigger phrases for an area are too narrow (LLM can't recognize intent).
 - Areas were collapsed too aggressively (too few areas — see Anti-Patterns).
 - ASCII `->` vs Unicode `→` mismatch — the harness now accepts both, but
@@ -293,49 +297,98 @@
 - The gbrain-bundled fixtures target skill names like `enrich`, `query`,
   `gmail`, `executive-assistant`. If your routing file doesn't expose
   those skills at all, expect strict-scoring failures on those fixtures.
+
+### Step 6 (MANDATORY): Verify routing accuracy — steps (( role: reference ))
+
+Gate 1: Structural verification. Confirms your `routing-eval.jsonl`
+fixtures still resolve to the right skills under the compressed routing file.
+> Run from the workspace whose routing file you just edited:
+
+```bash
+gbrain routing-eval --json
+```
+
+
+### Step 6 (MANDATORY): Verify routing accuracy — steps 2 (( role: reference ))
+
+Confirms a frontier
+LLM can still drill into the dispatcher list and reach sub-skills under
+your specific compression. Requires a gbrain repo checkout because the
+harness lives there. Copy your edited routing file into the harness's
+variants directory, then invoke the harness with `--variants` pointing
+at it:
+
+```bash
+# In your agent workspace, identify the routing file you just compressed.
+EDITED=/path/to/your/AGENTS.md       # or skills/RESOLVER.md, whichever you edited
+
+# In your gbrain repo checkout:
+cd /path/to/gbrain/evals/functional-area-resolver
+TMP=$(mktemp -d)/variants && mkdir -p "$TMP"
+cp "$EDITED" "$TMP/my-edit.md"
+
+# Run the harness against your file (sequential, ~75 calls × $0.0076 ≈ $0.57 on Opus).
+ANTHROPIC_API_KEY=... node harness.mjs --variants-dir "$TMP" --variants my-edit \
+                                       --model opus --parallel 3 --yes
+```
+
+
+### Step 6 (MANDATORY): Verify routing accuracy — steps 3 (( role: reference ))
+
+If the lenient (same-area) score on your variant drops below 95%, revert the
+compression and tune. Common causes:
+- A sub-skill was omitted from the `(dispatcher for: ...)` list.
+
+### Step 6 (MANDATORY): Verify routing accuracy — steps 4
+
   Lenient scoring stays accurate for any sub-skill present in your
   `(dispatcher for: ...)` lists.
 
 ### Step 7: Review the diff before committing
 
+
+### Step 7: Review the diff before committing — steps (( role: reference ))
+
 Show the user the proposed edit (or the actual git diff) and wait for
 explicit approval before staging. Same convention as `skills/book-mirror/SKILL.md`.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
 - Routing matches the canonical triggers in the frontmatter.
 - Compression is only performed when the preconditions in Step 1 pass (file ≥12KB AND clean working tree, or `--force`).
+- Privacy contract preserved: no fork-specific filesystem path literals (server-side brain home, OpenClaw fork home) leak into the compressed output.
+
+The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+
+
+### Contract — steps (( role: reference ))
+
 - The mandatory verification gate in Step 6 fires on the user's edited file, not on sample variants. The user runs `gbrain routing-eval --json` AND the gbrain-repo harness (`node harness.mjs --variants-dir <tmp> --variants my-edit`) before committing the compressed file.
-- Privacy contract preserved: no fork-specific filesystem path literals (server-side brain home, OpenClaw fork home) leak into the compressed output.
-
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
-
-## Output Format
+## Output Format (( role: template ))
 
 The compressed routing file follows the area-entry template documented in Step 4 ("Build the area entry format"). Each entry: `- **{Area Name}**: {trigger phrases} -> \`{dispatcher-skill}\` (dispatcher for: {sub-skill list})`. The dispatcher arrow may be either ASCII `->` (default in this template) or Unicode `→` (used in some production deployments); the gbrain harness accepts both.
 
-## Anti-Patterns
-
-- **Resolver-of-resolvers with pipe tables.** Tested and failed (see eval
+## Anti-Patterns (( role: reference ))
+
+- Tested and failed (see eval
   table). The LLM picks area names from the table instead of drilling into
   sub-skills.
 
-- **Removing sub-skill names.** Without the `(dispatcher for: ...)` list,
+- Removing sub-skill names. Without the `(dispatcher for: ...)` list,
   the LLM can't route to specific sub-skills. The list is the routing signal.
 
-- **Too few areas.** Collapsing to <5 areas makes each area too broad.
+- Collapsing to <5 areas makes each area too broad.
   12-15 areas is the sweet spot.
 
-- **Too many areas.** Defeats the purpose. If you have 50 areas, just keep
+- Defeats the purpose. If you have 50 areas, just keep
   individual rows.
 
-## Maintenance
+## Maintenance (( role: reference ))
 
 When adding a new skill:
 1. Identify its functional area.
-2. Add the skill name to that area's `(dispatcher for: ...)` list.
 3. Update the area's skill file with routing detail.
 4. Run the routing eval (Step 6) to verify.
 
@@ -344,11 +397,18 @@
 2. Add the area entry to the routing file.
 3. Run the routing eval (Step 6) to verify.
 
-## Changelog
-
-### v1.0.0 — 2026-05-11
+
+### Maintenance — steps
+
+2. Add the skill name to that area's `(dispatcher for: ...)` list.
+## Changelog (( role: reference ))
+
+### v1.0.0 — 2026-05-11 (( role: reference ))
+- Skill renamed from `compress-agents-md` to `functional-area-resolver`
+  pre-release; the contribution is the pattern, not the filename.
+
+
+### v1.0.0 — 2026-05-11 — steps (( role: reference ))
+
 - Initial version. Pattern shipped in gbrain v0.32.3.0 with a held-out A/B
   eval (see `evals/functional-area-resolver/`).
-- Skill renamed from `compress-agents-md` to `functional-area-resolver`
-  pre-release; the contribution is the pattern, not the filename.
-
```
