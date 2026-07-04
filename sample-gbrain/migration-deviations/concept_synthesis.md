# Deviation: concept_synthesis.meri

- Original: `concept-synthesis/SKILL.md`
- Ported: `concept_synthesis.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 256 -> 265 (+25 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `What this solves`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L23 `Architecture`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L85 `T1 Canon — full synthesis`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L132 `T3 / T4 — stub only (no LLM synthesis)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L150 `Output: cluster map at concepts/README.md`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L189 `Tier quality`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L205 `Cron integration`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L246 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 9/14 (64% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=8, template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L10 `What this solves`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L23 `Architecture`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L85 `T1 Canon — full synthesis`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L132 `T3 / T4 — stub only (no LLM synthesis)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L150 `Output: cluster map at concepts/README.md`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L189 `Tier quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L196 `Synthesis quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L205 `Cron integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L246 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/concept-synthesis/SKILL.md
+++ skills/concept_synthesis.meri
@@ -23,7 +23,7 @@
 > **Convention:** see [_brain-filing-rules.md](../_brain-filing-rules.md) —
 > output files under `concepts/` per the primary-subject rule.
 
-## What this solves
+## What this solves (( inert ))
 
 Many ingestion pipelines (signal-detector, idea-ingest, voice-note-ingest)
 create a concept page for every idea mentioned. Over months this produces:
@@ -36,7 +36,7 @@
 
 This skill transforms that raw material into a curated intellectual map.
 
-## Architecture
+## Architecture (( inert ))
 
 ```
 Phase 1: Dedup + merge (deterministic)
@@ -70,7 +70,10 @@
     └── Identify idea genealogies (concept A → evolved into concept B)
 ```
 
-## Invocation
+## Invocation (( inert ))
+
+
+### Invocation — steps (( inert ))
 
 The skill is markdown agent instructions. The agent uses gbrain's
 existing operations + LLM passes:
@@ -93,9 +96,9 @@
 #    and writes concepts/README.md with the full intellectual map.
 ```
 
-## Output: concept page format (post-synthesis)
-
-### T1 Canon — full synthesis
+## Output: concept page format (post-synthesis) (( inert ))
+
+### T1 Canon — full synthesis (( inert ))
 
 ```markdown
 ---
@@ -142,7 +145,7 @@
 [Full timeline with deduped entries, quotes, source links]
 ```
 
-### T3 / T4 — stub only (no LLM synthesis)
+### T3 / T4 — stub only (no LLM synthesis) (( inert ))
 
 ```markdown
 ---
@@ -160,7 +163,7 @@
 > "Quote from the source" — [Date](URL)
 ```
 
-## Output: cluster map at concepts/README.md
+## Output: cluster map at concepts/README.md (( inert ))
 
 ```markdown
 # Intellectual Universe
@@ -192,26 +195,30 @@
 ```
 
 ## Quality gates
+use judgment to follow the Quality gates guidance:
 
 ### Dedup quality
 - No two concept pages should be "the same idea in different words."
 - Aliases preserved in frontmatter for search.
 - Run `gbrain query "type:concept"` and spot-check the count reduction.
 
-### Tier quality
+### Tier quality (( inert ))
 - T1 should feel like "yes, that IS one of my recurring frameworks" —
   recognizable, recurring, sharp.
 - T2 should feel like "I'm working on this; it's getting clearer."
 - No concept should be T1 with < 4 months span or < 6 mentions.
 - No concept should be T4 with > 3 months span.
 
-### Synthesis quality
+### Synthesis quality (( inert ))
 - Captures evolution, not just repetition.
 - Uses verbatim quotes, not paraphrase.
+- Does NOT hallucinate sources or dates.
+
+
+#### Synthesis quality — steps
+
 - Links to related concepts (markdown links, not wiki-links).
-- Does NOT hallucinate sources or dates.
-
-## Cron integration
+## Cron integration (( inert ))
 
 This is heavy work. Run on a cadence, not on every signal:
 
@@ -221,7 +228,8 @@
 - Manual trigger for a full re-synthesis when the corpus shifts
   significantly.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Running synthesis on T3/T4 — wastes API budget on ideas that may
   never sharpen.
@@ -239,7 +247,8 @@
 - `skills/idea-ingest/SKILL.md` — same for links / articles
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -250,7 +259,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
