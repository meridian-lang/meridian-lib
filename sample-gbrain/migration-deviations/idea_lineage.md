# Deviation: idea_lineage.meri

- Original: `idea-lineage/SKILL.md`
- Ported: `idea_lineage.meri`
- Tier: 2 (light edits)
- Similarity: 56%
- Lines: 223 -> 225 (+100 / -98)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 6/14 inert (43% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=1, tools-metadata=1
- Judgment: 5 blocks, 50 lines

### Inert section details
- L11 `What this solves`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L28 `What this is not`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L126 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L156 `Quality Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L181 `Related Skills and Operations`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L189 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/idea-lineage/SKILL.md
+++ skills/idea_lineage.meri
@@ -35,7 +35,7 @@
 > the distinction between holder-attributed takes and the brain owner's hot
 > facts. Do not collapse those layers when summarizing lineage.
 
-## What this solves
+## What this solves (( inert ))
 
 Users often want to understand how one idea changed across time: when it first
 appeared, when it became sharp, what it displaced, what it contradicted, and
@@ -52,7 +52,7 @@
 - "What is my current version of this idea?"
 - "Where did this idea come from, and what did I abandon along the way?"
 
-## What this is not
+## What this is not (( inert ))
 
 - Not `concept-synthesis`: that skill deduplicates many concept stubs, tiers
   them, writes concept pages, and builds a broad intellectual map.
@@ -63,123 +63,124 @@
 - Not a writing mode by default: do not write a lineage page unless the user
   explicitly asks for a saved artifact after seeing the read-only answer.
 
-## Contract
-
-This skill guarantees:
-
-- A single-idea scope is preserved. Broad corpus or "map my concepts" prompts
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+
+!!! checklist (( ai-autonomy ))
+- [ ] A single-idea scope is preserved. Broad corpus or "map my concepts" prompts
   route to `skills/concept-synthesis/SKILL.md` instead.
-- Every lineage claim cites existing brain evidence: page slug, source id when
+- [ ] Every lineage claim cites existing brain evidence: page slug, source id when
   present, date, and short quote or snippet.
-- Missing evidence is labeled as a gap, not patched with plausible narrative.
-- Contradictions, reversals, and abandoned branches are separated from normal
+- [ ] Missing evidence is labeled as a gap, not patched with plausible narrative.
+- [ ] Contradictions, reversals, and abandoned branches are separated from normal
   temporal evolution.
-- The default mode is read-only and does not mutate brain pages.
+- [ ] The default mode is read-only and does not mutate brain pages.
 
 ## Phases
 
-### Phase 1: Resolve the idea target
-
-1. Restate the idea in one sentence.
-2. Search for exact phrase variants with `search`.
-3. Run one semantic `query` for the natural-language version.
-4. Check `list_pages` for concept pages when the idea has an obvious concept
-   slug or title.
-5. If results point to an entity/metric/status trajectory rather than a concept,
-   hand off to `find_trajectory` or the normal query/think trajectory path.
-
-If multiple distinct ideas share the same phrase, ask the user to choose the
-intended one before synthesizing.
-
-### Phase 2: Gather evidence
-
-Collect enough evidence to support or reject each output bucket:
-
-- Search chunks with dates and source slugs.
-- Full pages via `get_page` for the top relevant concept, note, transcript,
-  meeting, article, or project pages.
-- Related concept pages through backlinks, `related` frontmatter, or repeated
-  co-occurrence in search results.
-- Takes via `takes_search` when the idea appears as a belief, bet, hunch, or
-  attributed claim.
-- Cached contradiction findings via `find_contradictions` when the user asks
-  about inconsistency or the search results show obvious conflict.
-- `find_trajectory` only when the evidence is entity/attribute-shaped, such as
-  a role/status/metric evolution that is relevant to the idea's story.
-
-Prefer fewer high-quality sources over a long unsorted pile. Read full pages
-when snippets imply a lineage milestone.
-
-### Phase 3: Classify lineage moments
-
-Classify evidence into these buckets:
-
-1. **First mention** - earliest dated evidence where the idea appears.
-2. **Best articulation** - the clearest or most complete expression, not
-   necessarily the newest.
-3. **Current live version** - the most recent high-authority version that still
-   appears active.
-4. **Reversals** - places where the user's stance changed direction.
-5. **Contradictions** - claims that cannot both be true at the same time or
-   under the same assumptions. Distinguish these from legitimate temporal
-   supersession.
-6. **Abandoned branches** - promising variants that appear and then disappear,
-   lose support, or are explicitly rejected.
-7. **Related concepts** - nearby ideas that shaped or inherited part of the
-   original idea.
-
-When a bucket has no evidence, write "No clear evidence found" with a brief note
-about what was checked.
-
-### Phase 4: Synthesize the lineage
-
-Write the answer in the output format below. Keep the synthesis proportional to
-the evidence. Do not overfit a smooth evolution if the evidence is sparse,
-messy, or contradictory.
-
-### Phase 5: Suggest optional next action
-
-If useful, offer one concrete follow-up:
-
-- Save the lineage as a brain page.
-- Run broad `concept-synthesis` if the user actually wants the whole concept
-  map refreshed.
-- Run or inspect trajectory data if the idea turned out to depend on structured
-  entity facts.
-- Run a contradiction probe only when stale cached findings are insufficient
-  and the user explicitly wants that heavier pass.
-
+### Phase 1: Resolve the idea target (( role: procedure ))
+
+use judgment to follow the Phase 1: Resolve the idea target guidance:
+  1. Restate the idea in one sentence.
+  2. Search for exact phrase variants with `search`.
+  3. Run one semantic `query` for the natural-language version.
+  4. Check `list_pages` for concept pages when the idea has an obvious concept
+     slug or title.
+  5. If results point to an entity/metric/status trajectory rather than a concept,
+     hand off to `find_trajectory` or the normal query/think trajectory path.
+  
+  If multiple distinct ideas share the same phrase, ask the user to choose the
+  intended one before synthesizing.
+### Phase 2: Gather evidence (( role: procedure ))
+  
+use judgment to follow the Phase 2: Gather evidence guidance:
+  Collect enough evidence to support or reject each output bucket:
+  
+  item: Search chunks with dates and source slugs.
+  item: Full pages via `get_page` for the top relevant concept, note, transcript,
+    meeting, article, or project pages.
+  item: Related concept pages through backlinks, `related` frontmatter, or repeated
+    co-occurrence in search results.
+  item: Takes via `takes_search` when the idea appears as a belief, bet, hunch, or
+    attributed claim.
+  item: Cached contradiction findings via `find_contradictions` when the user asks
+    about inconsistency or the search results show obvious conflict.
+  item: `find_trajectory` only when the evidence is entity/attribute-shaped, such as
+    a role/status/metric evolution that is relevant to the idea's story.
+  
+  Prefer fewer high-quality sources over a long unsorted pile. Read full pages
+  when snippets imply a lineage milestone.
+### Phase 3: Classify lineage moments (( role: procedure ))
+  
+use judgment to follow the Phase 3: Classify lineage moments guidance:
+  Classify evidence into these buckets:
+  
+  1. **First mention** - earliest dated evidence where the idea appears.
+  2. **Best articulation** - the clearest or most complete expression, not
+     necessarily the newest.
+  3. **Current live version** - the most recent high-authority version that still
+     appears active.
+  4. **Reversals** - places where the user's stance changed direction.
+  5. **Contradictions** - claims that cannot both be true at the same time or
+     under the same assumptions. Distinguish these from legitimate temporal
+     supersession.
+  6. **Abandoned branches** - promising variants that appear and then disappear,
+     lose support, or are explicitly rejected.
+  7. **Related concepts** - nearby ideas that shaped or inherited part of the
+     original idea.
+  
+  When a bucket has no evidence, write "No clear evidence found" with a brief note
+  about what was checked.
+### Phase 4: Synthesize the lineage (( role: procedure ))
+  
+use judgment to follow the Phase 4: Synthesize the lineage guidance:
+  Write the answer in the output format below. Keep the synthesis proportional to
+  the evidence. Do not overfit a smooth evolution if the evidence is sparse,
+  messy, or contradictory.
+### Phase 5: Suggest optional next action (( role: procedure ))
+  
+use judgment to follow the Phase 5: Suggest optional next action guidance:
+  If useful, offer one concrete follow-up:
+  
+  item: Save the lineage as a brain page.
+  item: Run broad `concept-synthesis` if the user actually wants the whole concept
+    map refreshed.
+  item: Run or inspect trajectory data if the idea turned out to depend on structured
+    entity facts.
+  item: Run a contradiction probe only when stale cached findings are insufficient
+    and the user explicitly wants that heavier pass.
 ## Output Format
 
 Use this shape for normal answers:
 
 ```markdown
-## Current Live Version
+## Current Live Version (( inert ))
 [1-3 sentences. Include confidence: high / medium / low.]
 
-## Lineage
+## Lineage (( inert ))
 - First mention: [date] - [claim] ([source-id:slug], "short quote")
 - Best articulation: [date] - [claim] ([source-id:slug], "short quote")
 - Turning point: [date] - [what changed] ([source-id:slug])
 
-## Reversals and Contradictions
+## Reversals and Contradictions (( inert ))
 - Reversal: [what changed, with before/after evidence]
 - Contradiction: [what conflicts, or "No clear evidence found"]
 
-## Abandoned Branches
+## Abandoned Branches (( inert ))
 - [branch] - [why it appears abandoned, with evidence]
 
-## Related Concepts
+## Related Concepts (( inert ))
 - [concept slug or title] - [relationship]
 
-## Evidence Gaps
+## Evidence Gaps (( inert ))
 - [bucket or claim] - [what was checked and what is missing]
 ```
 
 For short answers, collapse sections, but keep the same distinctions. Always
 cite the source for each non-gap claim.
 
-## Quality Rules
+## Quality Rules (( inert ))
 
 - Quote exact text when naming first mention or best articulation.
 - Include dates when the source has dates. If no date is available, say
@@ -192,18 +193,19 @@
   undated page, or a fuzzy semantic match.
 - Preserve source ids in citations when search or page payloads include them.
 
-## Anti-Patterns
-
-- Running `concept-synthesis` for a single-idea question.
-- Presenting an entity's MRR, ARR, role, or status trajectory as conceptual
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Running `concept-synthesis` for a single-idea question.
+- [ ] Presenting an entity's MRR, ARR, role, or status trajectory as conceptual
   lineage without explaining the distinction.
-- Treating normal temporal evolution as contradiction.
-- Inventing abandoned branches because the story would be more interesting.
-- Saving or rewriting brain pages without explicit user instruction.
-- Using real names, companies, funds, or fork-specific examples in bundled
+- [ ] Treating normal temporal evolution as contradiction.
+- [ ] Inventing abandoned branches because the story would be more interesting.
+- [ ] Saving or rewriting brain pages without explicit user instruction.
+- [ ] Using real names, companies, funds, or fork-specific examples in bundled
   fixtures or documentation.
 
-## Related Skills and Operations
+## Related Skills and Operations (( inert ))
 
 - `skills/concept-synthesis/SKILL.md` - broad mutating concept-map synthesis.
 - `skills/query/SKILL.md` - general brain search and cited answers.
```
