# Deviation: concept_synthesis.meri

- Original: `concept-synthesis/SKILL.md`
- Ported: `concept_synthesis.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 256 -> 258 (+66 / -64)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 13/16 inert (81% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=12, template=1
- Judgment: 1 blocks, 15 lines

### Inert section details
- L10 `What this solves`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L23 `Architecture`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L80 `Output: concept page format (post-synthesis)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L82 `T1 Canon — full synthesis`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L129 `T3 / T4 — stub only (no LLM synthesis)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L147 `Output: cluster map at concepts/README.md`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L178 `Quality gates`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L180 `Dedup quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L185 `Tier quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L192 `Synthesis quality`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L198 `Cron integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L220 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L239 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -70,32 +70,32 @@
     └── Identify idea genealogies (concept A → evolved into concept B)
 ```
 
-## Invocation
-
-The skill is markdown agent instructions. The agent uses gbrain's
-existing operations + LLM passes:
-
-```bash
-# 1. List all concept pages
-gbrain query "type:concept" --limit 10000 --json
-
-# 2. Phase 1 dedup — agent applies Jaccard + substring locally,
-#    then LLM passes to identify semantic duplicates.
-
-# 3. Phase 2 tier — agent scores each canonical concept based on
-#    frequency / timespan / breadth and writes tier into frontmatter.
-
-# 4. Phase 3 synthesis — for each T1/T2, agent reads the timeline
-#    + associated source pages and writes a synthesis section
-#    onto the concept page via put_page.
-
-# 5. Phase 4 clustering — agent reads the tiered concept list
-#    and writes concepts/README.md with the full intellectual map.
-```
-
-## Output: concept page format (post-synthesis)
-
-### T1 Canon — full synthesis
+## Invocation (( role: procedure ))
+
+use judgment to follow the Invocation guidance:
+  The skill is markdown agent instructions. The agent uses gbrain's
+  existing operations + LLM passes:
+  
+  ```bash
+  # 1. List all concept pages
+  gbrain query "type:concept" --limit 10000 --json
+  
+  # 2. Phase 1 dedup — agent applies Jaccard + substring locally,
+  #    then LLM passes to identify semantic duplicates.
+  
+  # 3. Phase 2 tier — agent scores each canonical concept based on
+  #    frequency / timespan / breadth and writes tier into frontmatter.
+  
+  # 4. Phase 3 synthesis — for each T1/T2, agent reads the timeline
+  #    + associated source pages and writes a synthesis section
+  #    onto the concept page via put_page.
+  
+  # 5. Phase 4 clustering — agent reads the tiered concept list
+  #    and writes concepts/README.md with the full intellectual map.
+  ```
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
@@ -134,15 +134,15 @@
 | YYYY-MM | "Sharpening" | Anti-pattern emerges |
 | YYYY-MM | "Peak form" | Cleanest expression |
 
-## Related Concepts
+## Related Concepts (( inert ))
 - [sibling concept](sibling-concept.md) — relationship description
 - [sibling concept](sibling-concept.md) — relationship description
 
-## Timeline
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
 
-### [Cluster Name]
+### [Cluster Name] (( inert ))
 - [concept-slug](concept-slug.md) — one-line characterization
 - ...
 
-### [Other Cluster]
+### [Other Cluster] (( inert ))
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
 
@@ -221,34 +221,36 @@
 - Manual trigger for a full re-synthesis when the corpus shifts
   significantly.
 
-## Anti-Patterns
-
-- ❌ Running synthesis on T3/T4 — wastes API budget on ideas that may
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Running synthesis on T3/T4 — wastes API budget on ideas that may
   never sharpen.
-- ❌ Hallucinating quotes or dates. The timeline must be verifiable
+- [ ] ❌ Hallucinating quotes or dates. The timeline must be verifiable
   against existing brain pages.
-- ❌ Generic cluster names ("Various Topics"). If you can't name the
+- [ ] ❌ Generic cluster names ("Various Topics"). If you can't name the
   cluster, the cluster isn't real.
-- ❌ Re-synthesizing already-synthesized T1s without new source material.
+- [ ] ❌ Re-synthesizing already-synthesized T1s without new source material.
   Idempotency-respect.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/signal-detector/SKILL.md` — creates raw concept stubs from text channels
 - `skills/voice-note-ingest/SKILL.md` — same for audio channels
 - `skills/idea-ingest/SKILL.md` — same for links / articles
 
 
-## Contract
-
-This skill guarantees:
-
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
-
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+
+!!! checklist (( ai-autonomy ))
+- [ ] Routing matches the canonical triggers in the frontmatter.
+- [ ] Output written under the directories listed in `writes_to:` (when applicable).
+- [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+- [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+
+> The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
 ## Output Format
 
```
