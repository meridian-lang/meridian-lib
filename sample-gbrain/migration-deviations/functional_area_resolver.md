# Deviation: functional_area_resolver.meri

- Original: `functional-area-resolver/SKILL.md`
- Ported: `functional_area_resolver.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 354 -> 354 (+27 / -27)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 26/26 inert (100% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/functional-area-resolver/SKILL.md
+++ functional_area_resolver.meri
@@ -36,18 +36,18 @@
 
 # Functional-Area Resolver — Pattern for Compressing Routing Tables
 
-## Problem
+## Problem (( inert ))
 
 Routing files (RESOLVER.md, AGENTS.md) grow as skills are added. Each skill
 gets its own row (trigger -> skill path). At ~200+ skills this hits 25-30KB,
 eating context budget that should go to actual work.
 
-## Solution: Functional-Area Dispatchers
+## Solution: Functional-Area Dispatchers (( inert ))
 
 Replace N rows per area with **one entry per functional area**. Each entry
 lists all sub-skills it can dispatch to in a `(dispatcher for: ...)` clause.
 
-### Before (270 rows, 25KB)
+### Before (270 rows, 25KB) (( inert ))
 ```
 - Creating/enriching a person or company page -> `enrich`
 - Fix broken citations in brain pages -> `citation-fixer`
@@ -59,7 +59,7 @@
 ...
 ```
 
-### After (13 rows, 13KB)
+### After (13 rows, 13KB) (( inert ))
 ```
 - **Brain & knowledge**: create/enrich/search/export brain pages, filing,
   citations, publishing, book analysis, strategic reading, concept synthesis,
@@ -68,7 +68,7 @@
   strategic-reading, concept-synthesis, archive-crawler, ...)
 ```
 
-## Why It Works
+## Why It Works (( inert ))
 
 The LLM doesn't need one row per sub-skill. It needs:
 1. **Area recognition** — "this is about brain pages" -> Brain & Knowledge
@@ -78,7 +78,7 @@
 This is a **two-layer dispatch**: routing file routes to the area, the area
 skill routes to the specific sub-skill. Each layer does one job well.
 
-## A/B Eval Results
+## A/B Eval Results (( inert ))
 
 Three resolver architectures tested across three Anthropic frontier models
 (Opus 4.7, Sonnet 4.6, Haiku 4.5) on real production AGENTS.md content,
@@ -93,7 +93,7 @@
   production behavior — an agent that lands in `gmail` for an email intent
   succeeds even if the resolver entry said `executive-assistant`.
 
-### Training corpus (n=20, 3 seeds × 3 variants × 3 models, LENIENT)
+### Training corpus (n=20, 3 seeds × 3 variants × 3 models, LENIENT) (( inert ))
 
 | Variant | Opus 4.7 | Sonnet 4.6 | Haiku 4.5 | Size |
 |---|---|---|---|---|
@@ -101,7 +101,7 @@
 | **functional-areas** (this pattern) | **98.3% ± 7.2%** | **100% ± 0%** | **88.3% ± 7.2%** | **13KB** |
 | resolver-of-resolvers (no dispatcher clause) | 63.3% ± 14.3% | 41.7% ± 7.2% | 65.0% ± 12.4% | 10KB |
 
-### Held-out blind corpus (n=5, 3 seeds, LENIENT)
+### Held-out blind corpus (n=5, 3 seeds, LENIENT) (( inert ))
 
 | Variant | Opus 4.7 | Sonnet 4.6 | Haiku 4.5 |
 |---|---|---|---|
@@ -109,7 +109,7 @@
 | **functional-areas** | **100% ± 0%** | **100% ± 0%** | **100% ± 0%** |
 | resolver-of-resolvers | 100% ± 0% | **73.3% ± 28.7%** | 100% ± 0% |
 
-### What the data shows
+### What the data shows (( inert ))
 
 1. **Functional-areas BEATS baseline on training across all three models** (+13 to +17pp) at 48% the size. Held-out is saturated at 100% for both — within margin of error.
 
@@ -119,7 +119,7 @@
 
 4. **The pattern's value scales with model tier.** Compression gain (functional-areas vs baseline, training, LENIENT) is +17pp on Opus, +13pp on Sonnet, +15pp on Haiku. Sonnet shows the cleanest separation between functional-areas and resolver-of-resolvers (100% vs 41.7%) — model capacity affects how much the dispatcher signal matters.
 
-### Reproduce
+### Reproduce (( inert ))
 
 ```bash
 cd evals/functional-area-resolver
@@ -132,7 +132,7 @@
 Receipts (model, prompt_template_hash, fixtures_hash, harness_sha, ts):
 `evals/functional-area-resolver/baseline-runs/2026-05-11-{opus-4-7,sonnet-4-6,haiku-4-5}.jsonl`.
 
-### Methodology caveats
+### Methodology caveats (( inert ))
 
 - **Production prompt matters.** With a naive "return the skill slug" prompt
   (no instruction about `(dispatcher for: ...)`), every compression variant
@@ -150,7 +150,7 @@
   the harness can't distinguish between "100%" and "95% with one nondeterministic
   miss." Expanding to ≥20 is a v0.33.x follow-up.
 
-### Prior work and citations
+### Prior work and citations (( inert ))
 
 The pattern is a **static-prompt analog of hierarchical agent routing**, a
 2024-2025 research direction:
@@ -176,9 +176,9 @@
 routing accuracy — is the open contribution. See
 `evals/functional-area-resolver/README.md` for methodology details.
 
-## How To Compress
-
-### Step 1: Preconditions
+## How To Compress (( inert ))
+
+### Step 1: Preconditions (( inert ))
 
 Refuse to compress if either gate fails:
 - Source routing file is under 12KB (compression overhead exceeds benefit).
@@ -187,7 +187,7 @@
 
 If a user wants to override either gate, they ask explicitly with `--force`.
 
-### Step 2: When to compress which file
+### Step 2: When to compress which file (( inert ))
 
 GBrain workspaces often have TWO routing files merged at runtime (per
 `src/core/check-resolvable.ts` v0.31.7): `skills/RESOLVER.md` and a sibling
@@ -201,7 +201,7 @@
 If the deployment uses only one routing file, this section is a no-op —
 compress that one.
 
-### Step 3: Identify functional areas
+### Step 3: Identify functional areas (( inert ))
 
 Group skills by domain. Typical areas (adjust per deployment):
 
@@ -217,7 +217,7 @@
 - **Tasks & Logistics** — daily-task-manager as dispatcher
 - **People & Contacts** — google-contacts as dispatcher
 
-### Step 4: Build the area entry format
+### Step 4: Build the area entry format (( inert ))
 
 Each area entry follows this template:
 
@@ -232,12 +232,12 @@
 - Sub-skill list should be comprehensive — this is how the LLM knows what's available
 - The dispatcher skill file should have its own internal routing table
 
-### Step 5: Keep always-on entries separate
+### Step 5: Keep always-on entries separate (( inert ))
 
 Gates and always-on entries (acknowledge, multi-user, entity-detector, etc.)
 stay as individual rows — they're checked on every message, not dispatched.
 
-### Step 6 (MANDATORY): Verify routing accuracy
+### Step 6 (MANDATORY): Verify routing accuracy (( inert ))
 
 Run two gates before committing the compressed file. Do NOT commit if either
 fails.
@@ -296,12 +296,12 @@
   Lenient scoring stays accurate for any sub-skill present in your
   `(dispatcher for: ...)` lists.
 
-### Step 7: Review the diff before committing
+### Step 7: Review the diff before committing (( inert ))
 
 Show the user the proposed edit (or the actual git diff) and wait for
 explicit approval before staging. Same convention as `skills/book-mirror/SKILL.md`.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -316,7 +316,7 @@
 
 The compressed routing file follows the area-entry template documented in Step 4 ("Build the area entry format"). Each entry: `- **{Area Name}**: {trigger phrases} -> \`{dispatcher-skill}\` (dispatcher for: {sub-skill list})`. The dispatcher arrow may be either ASCII `->` (default in this template) or Unicode `→` (used in some production deployments); the gbrain harness accepts both.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Resolver-of-resolvers with pipe tables.** Tested and failed (see eval
   table). The LLM picks area names from the table instead of drilling into
@@ -331,7 +331,7 @@
 - **Too many areas.** Defeats the purpose. If you have 50 areas, just keep
   individual rows.
 
-## Maintenance
+## Maintenance (( inert ))
 
 When adding a new skill:
 1. Identify its functional area.
@@ -344,9 +344,9 @@
 2. Add the area entry to the routing file.
 3. Run the routing eval (Step 6) to verify.
 
-## Changelog
-
-### v1.0.0 — 2026-05-11
+## Changelog (( inert ))
+
+### v1.0.0 — 2026-05-11 (( inert ))
 - Initial version. Pattern shipped in gbrain v0.32.3.0 with a held-out A/B
   eval (see `evals/functional-area-resolver/`).
 - Skill renamed from `compress-agents-md` to `functional-area-resolver`
```
