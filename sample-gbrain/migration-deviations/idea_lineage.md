# Deviation: idea_lineage.meri

- Original: `idea-lineage/SKILL.md`
- Ported: `idea_lineage.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 223 -> 232 (+16 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L11 `What this solves`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L28 `What this is not`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L132 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L196 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 4/14 (29% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=1, tools-metadata=1
- Judgment: 9 blocks, 0 lines

### Inert section details
- L11 `What this solves`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L28 `What this is not`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L132 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L196 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
@@ -63,7 +63,8 @@
 - Not a writing mode by default: do not write a lineage page unless the user
   explicitly asks for a saved artifact after seeing the read-only answer.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -77,8 +78,10 @@
 - The default mode is read-only and does not mutate brain pages.
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 ### Phase 1: Resolve the idea target
+use judgment to follow the Phase 1: Resolve the idea target guidance:
 
 1. Restate the idea in one sentence.
 2. Search for exact phrase variants with `search`.
@@ -92,6 +95,7 @@
 intended one before synthesizing.
 
 ### Phase 2: Gather evidence
+use judgment to follow the Phase 2: Gather evidence guidance:
 
 Collect enough evidence to support or reject each output bucket:
 
@@ -111,6 +115,7 @@
 when snippets imply a lineage milestone.
 
 ### Phase 3: Classify lineage moments
+use judgment to follow the Phase 3: Classify lineage moments guidance:
 
 Classify evidence into these buckets:
 
@@ -132,12 +137,14 @@
 about what was checked.
 
 ### Phase 4: Synthesize the lineage
+use judgment to follow the Phase 4: Synthesize the lineage guidance:
 
 Write the answer in the output format below. Keep the synthesis proportional to
 the evidence. Do not overfit a smooth evolution if the evidence is sparse,
 messy, or contradictory.
 
 ### Phase 5: Suggest optional next action
+use judgment to follow the Phase 5: Suggest optional next action guidance:
 
 If useful, offer one concrete follow-up:
 
@@ -149,7 +156,7 @@
 - Run a contradiction probe only when stale cached findings are insufficient
   and the user explicitly wants that heavier pass.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Use this shape for normal answers:
 
@@ -179,7 +186,8 @@
 For short answers, collapse sections, but keep the same distinctions. Always
 cite the source for each non-gap claim.
 
-## Quality Rules
+## Quality Rules (( role: procedure ))
+use judgment to follow the Quality Rules guidance:
 
 - Quote exact text when naming first mention or best articulation.
 - Include dates when the source has dates. If no date is available, say
@@ -192,7 +200,8 @@
   undated page, or a fuzzy semantic match.
 - Preserve source ids in citations when search or page payloads include them.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Running `concept-synthesis` for a single-idea question.
 - Presenting an entity's MRR, ARR, role, or status trajectory as conceptual
@@ -211,7 +220,7 @@
 - `find_trajectory` - structured typed-fact and event timelines for entities.
 - `find_contradictions` - cached suspected contradiction findings.
 
-## Tools Used
+## Tools Used (( inert, role: tools ))
 
 - `search` - keyword search for exact phrase variants and dated mentions.
 - `query` - semantic search for conceptual matches.
```
