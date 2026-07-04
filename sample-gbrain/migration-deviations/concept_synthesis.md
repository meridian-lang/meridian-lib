# Deviation: concept_synthesis.meri

- Original: `concept-synthesis/SKILL.md`
- Ported: `concept_synthesis.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 256 -> 256 (+29 / -29)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `What this solves`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L23 `Architecture`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L57 `Invocation`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L80 `Output: concept page format (post-synthesis)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L82 `T1 Canon — full synthesis`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L129 `T3 / T4 — stub only (no LLM synthesis)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L147 `Output: cluster map at concepts/README.md`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L178 `Quality gates`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L180 `Dedup quality`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L185 `Tier quality`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L192 `Synthesis quality`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L198 `Cron integration`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L208 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L226 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L237 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections: 15/16 inert (94% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=1, reference-documentation=12, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L10 `What this solves`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L23 `Architecture`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L57 `Invocation`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L80 `Output: concept page format (post-synthesis)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L82 `T1 Canon — full synthesis`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L129 `T3 / T4 — stub only (no LLM synthesis)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L147 `Output: cluster map at concepts/README.md`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L178 `Quality gates`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L180 `Dedup quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L185 `Tier quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L192 `Synthesis quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L198 `Cron integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L208 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L226 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L237 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -70,7 +70,7 @@
     └── Identify idea genealogies (concept A → evolved into concept B)
 ```
 
-## Invocation
+## Invocation (( inert ))
 
 The skill is markdown agent instructions. The agent uses gbrain's
 existing operations + LLM passes:
@@ -93,9 +93,9 @@
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
@@ -116,17 +116,17 @@
 
 **Tier 1 — Canon** | 18 mentions across 8 months
 
-## Synthesis
+## Synthesis (( inert ))
 
 [2-4 paragraph narrative tracing how the idea evolved, what it means in
 the user's worldview, why it matters. Third-person analytical voice.]
 
-## Best Articulation
+## Best Articulation (( inert ))
 
 > "Verbatim quote from a source — the most precise or highest-engagement
 > expression of this idea." — [Date](source-url)
 
-## Evolution
+## Evolution (( inert ))
 
 | Period | Expression | Signal |
 |--------|-----------|--------|
@@ -135,14 +135,14 @@
 | YYYY-MM | "Peak form" | Cleanest expression |
 
 ## Related Concepts
-- [sibling concept](sibling-concept.md) — relationship description
-- [sibling concept](sibling-concept.md) — relationship description
-
-## Timeline
+- sibling concept — relationship description
+- sibling concept — relationship description
+
+## Timeline (( inert ))
 [Full timeline with deduped entries, quotes, source links]
 ```
 
-### T3 / T4 — stub only (no LLM synthesis)
+### T3 / T4 — stub only (no LLM synthesis) (( inert ))
 
 ```markdown
 ---
@@ -160,28 +160,28 @@
 > "Quote from the source" — [Date](URL)
 ```
 
-## Output: cluster map at concepts/README.md
+## Output: cluster map at concepts/README.md (( inert ))
 
 ```markdown
 # Intellectual Universe
 
-## Canon (T1) — N concepts
+## Canon (T1) — N concepts (( inert ))
 The permanent intellectual fingerprint. Ideas that recur across years.
 
 ### [Cluster Name]
-- [concept-slug](concept-slug.md) — one-line characterization
+- concept-slug — one-line characterization
 - ...
 
 ### [Other Cluster]
 - ...
 
-## Developing (T2) — N concepts
+## Developing (T2) — N concepts (( inert ))
 Sharpening. Might become canon.
 
-## Speculative (T3) — N concepts
+## Speculative (T3) — N concepts (( inert ))
 Testing in public.
 
-## Stats
+## Stats (( inert ))
 - Total concepts: N
 - T1 Canon: N
 - T2 Developing: N
@@ -191,27 +191,27 @@
 - Latest source: YYYY-MM-DD
 ```
 
-## Quality gates
-
-### Dedup quality
+## Quality gates (( inert ))
+
+### Dedup quality (( inert ))
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
 - Links to related concepts (markdown links, not wiki-links).
 - Does NOT hallucinate sources or dates.
 
-## Cron integration
+## Cron integration (( inert ))
 
 This is heavy work. Run on a cadence, not on every signal:
 
@@ -221,7 +221,7 @@
 - Manual trigger for a full re-synthesis when the corpus shifts
   significantly.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Running synthesis on T3/T4 — wastes API budget on ideas that may
   never sharpen.
@@ -239,7 +239,7 @@
 - `skills/idea-ingest/SKILL.md` — same for links / articles
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -250,7 +250,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
