# Deviation: concept_synthesis.meri

- Original: `concept-synthesis/SKILL.md`
- Ported: `concept_synthesis.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 256 -> 269 (+33 / -20)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `What this solves`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Architecture`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L85 `T1 Canon — full synthesis`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L132 `T3 / T4 — stub only (no LLM synthesis)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L150 `Output: cluster map at concepts/README.md`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L183 `Dedup quality`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Tier quality`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L204 `Cron integration`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L239 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L250 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 12/13 (92% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=11, template=1
- Judgment: 1 blocks, 0 lines

### Inert section details
- L10 `What this solves`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Architecture`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L85 `T1 Canon — full synthesis`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L132 `T3 / T4 — stub only (no LLM synthesis)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L150 `Output: cluster map at concepts/README.md`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L183 `Dedup quality`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Tier quality`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L195 `Synthesis quality`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L204 `Cron integration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L214 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L239 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L250 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/concept-synthesis/SKILL.md
+++ skills/concept_synthesis.meri
@@ -23,7 +23,7 @@
 > **Convention:** see [_brain-filing-rules.md](../_brain-filing-rules.md) —
 > output files under `concepts/` per the primary-subject rule.
 
-## What this solves
+## What this solves (( role: reference ))
 
 Many ingestion pipelines (signal-detector, idea-ingest, voice-note-ingest)
 create a concept page for every idea mentioned. Over months this produces:
@@ -36,7 +36,7 @@
 
 This skill transforms that raw material into a curated intellectual map.
 
-## Architecture
+## Architecture (( role: reference ))
 
 ```
 Phase 1: Dedup + merge (deterministic)
@@ -72,6 +72,9 @@
 
 ## Invocation
 
+
+### Invocation — steps (( role: reference ))
+
 The skill is markdown agent instructions. The agent uses gbrain's
 existing operations + LLM passes:
 
@@ -93,9 +96,9 @@
 #    and writes concepts/README.md with the full intellectual map.
 ```
 
-## Output: concept page format (post-synthesis)
-
-### T1 Canon — full synthesis
+## Output: concept page format (post-synthesis) (( role: reference ))
+
+### T1 Canon — full synthesis (( role: reference ))
 
 ```markdown
 ---
@@ -142,7 +145,7 @@
 [Full timeline with deduped entries, quotes, source links]
 ```
 
-### T3 / T4 — stub only (no LLM synthesis)
+### T3 / T4 — stub only (no LLM synthesis) (( role: reference ))
 
 ```markdown
 ---
@@ -160,7 +163,7 @@
 > "Quote from the source" — [Date](URL)
 ```
 
-## Output: cluster map at concepts/README.md
+## Output: cluster map at concepts/README.md (( role: reference ))
 
 ```markdown
 # Intellectual Universe
@@ -193,25 +196,28 @@
 
 ## Quality gates
 
-### Dedup quality
+### Dedup quality (( role: reference ))
 - No two concept pages should be "the same idea in different words."
 - Aliases preserved in frontmatter for search.
 - Run `gbrain query "type:concept"` and spot-check the count reduction.
 
-### Tier quality
+### Tier quality (( role: reference ))
 - T1 should feel like "yes, that IS one of my recurring frameworks" —
   recognizable, recurring, sharp.
 - T2 should feel like "I'm working on this; it's getting clearer."
 - No concept should be T1 with < 4 months span or < 6 mentions.
 - No concept should be T4 with > 3 months span.
 
-### Synthesis quality
+### Synthesis quality (( role: reference ))
 - Captures evolution, not just repetition.
 - Uses verbatim quotes, not paraphrase.
+- Does NOT hallucinate sources or dates.
+
+
+### Synthesis quality — steps
+
 - Links to related concepts (markdown links, not wiki-links).
-- Does NOT hallucinate sources or dates.
-
-## Cron integration
+## Cron integration (( role: reference ))
 
 This is heavy work. Run on a cadence, not on every signal:
 
@@ -221,17 +227,24 @@
 - Manual trigger for a full re-synthesis when the corpus shifts
   significantly.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
+
+- ❌ Generic cluster names ("Various Topics"). If you can't name the
+  cluster, the cluster isn't real.
+  Idempotency-respect.
+
+
+### Anti-Patterns — steps (( role: reference ))
 
 - ❌ Running synthesis on T3/T4 — wastes API budget on ideas that may
   never sharpen.
 - ❌ Hallucinating quotes or dates. The timeline must be verifiable
   against existing brain pages.
-- ❌ Generic cluster names ("Various Topics"). If you can't name the
-  cluster, the cluster isn't real.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps 2 guidance:
 - ❌ Re-synthesizing already-synthesized T1s without new source material.
-  Idempotency-respect.
-
 ## Related skills
 
 - `skills/signal-detector/SKILL.md` — creates raw concept stubs from text channels
@@ -239,7 +252,7 @@
 - `skills/idea-ingest/SKILL.md` — same for links / articles
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -250,7 +263,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
