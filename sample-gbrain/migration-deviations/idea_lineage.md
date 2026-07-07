# Deviation: idea_lineage.meri

- Original: `idea-lineage/SKILL.md`
- Ported: `idea_lineage.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 223 -> 243 (+48 / -28)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L32 `What this is not`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L145 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L175 `Quality Rules`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L207 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 11/13 (85% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=9, template=1, tools-metadata=1
- Judgment: 2 blocks, 0 lines

### Inert section details
- L11 `What this solves`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `What this is not`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L58 `Phase 1: Resolve the idea target`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L78 `Phase 2: Gather evidence`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L100 `Phase 3: Classify lineage moments`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L130 `Phase 5: Suggest optional next action`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L145 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L175 `Quality Rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L188 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L207 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/idea-lineage/SKILL.md
+++ skills/idea_lineage.meri
@@ -35,24 +35,28 @@
 > the distinction between holder-attributed takes and the brain owner's hot
 > facts. Do not collapse those layers when summarizing lineage.
 
-## What this solves
-
+## What this solves (( role: reference ))
+
+Use this skill when the user asks about one idea, topic, phrase, or concept
+page and wants its evolution through the brain.
+
+Canonical examples:
+
+- "Run idea lineage on founder-led sales."
+- "How has my thinking about compounding trust changed?"
+- "What is my current version of this idea?"
+- "Where did this idea come from, and what did I abandon along the way?"
+
+
+### What this solves — steps
+
+use judgment to follow the What this solves — steps guidance:
 Users often want to understand how one idea changed across time: when it first
 appeared, when it became sharp, what it displaced, what it contradicted, and
 what version is alive now. That is different from building a whole concept map
 and different from charting an entity's metric trajectory.
 
-Use this skill when the user asks about one idea, topic, phrase, or concept
-page and wants its evolution through the brain.
-
-Canonical examples:
-
-- "Run idea lineage on founder-led sales."
-- "How has my thinking about compounding trust changed?"
-- "What is my current version of this idea?"
-- "Where did this idea come from, and what did I abandon along the way?"
-
-## What this is not
+## What this is not (( role: reference ))
 
 - Not `concept-synthesis`: that skill deduplicates many concept stubs, tiers
   them, writes concept pages, and builds a broad intellectual map.
@@ -63,7 +67,7 @@
 - Not a writing mode by default: do not write a lineage page unless the user
   explicitly asks for a saved artifact after seeing the read-only answer.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -78,20 +82,27 @@
 
 ## Phases
 
-### Phase 1: Resolve the idea target
+### Phase 1: Resolve the idea target (( role: reference ))
 
 1. Restate the idea in one sentence.
-2. Search for exact phrase variants with `search`.
 3. Run one semantic `query` for the natural-language version.
 4. Check `list_pages` for concept pages when the idea has an obvious concept
    slug or title.
 5. If results point to an entity/metric/status trajectory rather than a concept,
    hand off to `find_trajectory` or the normal query/think trajectory path.
 
+
+### Phase 1: Resolve the idea target — steps
+
+2. Search for exact phrase variants with `search`.
+
+### Phase 1: Resolve the idea target — steps 2
+
+use judgment to follow the Phase 1: Resolve the idea target — steps 2 guidance:
 If multiple distinct ideas share the same phrase, ask the user to choose the
 intended one before synthesizing.
 
-### Phase 2: Gather evidence
+### Phase 2: Gather evidence (( role: reference ))
 
 Collect enough evidence to support or reject each output bucket:
 
@@ -104,13 +115,16 @@
   attributed claim.
 - Cached contradiction findings via `find_contradictions` when the user asks
   about inconsistency or the search results show obvious conflict.
+Prefer fewer high-quality sources over a long unsorted pile. Read full pages
+when snippets imply a lineage milestone.
+
+
+### Phase 2: Gather evidence — steps
+
 - `find_trajectory` only when the evidence is entity/attribute-shaped, such as
   a role/status/metric evolution that is relevant to the idea's story.
 
-Prefer fewer high-quality sources over a long unsorted pile. Read full pages
-when snippets imply a lineage milestone.
-
-### Phase 3: Classify lineage moments
+### Phase 3: Classify lineage moments (( role: reference ))
 
 Classify evidence into these buckets:
 
@@ -128,6 +142,9 @@
 7. **Related concepts** - nearby ideas that shaped or inherited part of the
    original idea.
 
+
+### Phase 3: Classify lineage moments — steps (( role: reference ))
+
 When a bucket has no evidence, write "No clear evidence found" with a brief note
 about what was checked.
 
@@ -137,19 +154,22 @@
 the evidence. Do not overfit a smooth evolution if the evidence is sparse,
 messy, or contradictory.
 
-### Phase 5: Suggest optional next action
+### Phase 5: Suggest optional next action (( role: reference ))
 
 If useful, offer one concrete follow-up:
 
 - Save the lineage as a brain page.
-- Run broad `concept-synthesis` if the user actually wants the whole concept
-  map refreshed.
 - Run or inspect trajectory data if the idea turned out to depend on structured
   entity facts.
 - Run a contradiction probe only when stale cached findings are insufficient
   and the user explicitly wants that heavier pass.
 
-## Output Format
+
+### Phase 5: Suggest optional next action — steps
+
+- Run broad `concept-synthesis` if the user actually wants the whole concept
+  map refreshed.
+## Output Format (( role: template ))
 
 Use this shape for normal answers:
 
@@ -179,7 +199,7 @@
 For short answers, collapse sections, but keep the same distinctions. Always
 cite the source for each non-gap claim.
 
-## Quality Rules
+## Quality Rules (( role: reference ))
 
 - Quote exact text when naming first mention or best articulation.
 - Include dates when the source has dates. If no date is available, say
@@ -192,7 +212,7 @@
   undated page, or a fuzzy semantic match.
 - Preserve source ids in citations when search or page payloads include them.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Running `concept-synthesis` for a single-idea question.
 - Presenting an entity's MRR, ARR, role, or status trajectory as conceptual
@@ -211,7 +231,7 @@
 - `find_trajectory` - structured typed-fact and event timelines for entities.
 - `find_contradictions` - cached suspected contradiction findings.
 
-## Tools Used
+## Tools Used (( role: tools ))
 
 - `search` - keyword search for exact phrase variants and dated mentions.
 - `query` - semantic search for conceptual matches.
```
