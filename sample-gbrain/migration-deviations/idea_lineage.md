# Deviation: idea_lineage.meri

- Original: `idea-lineage/SKILL.md`
- Ported: `idea_lineage.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 223 -> 223 (+18 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 13/14 inert (93% inert ratio)
- Judgment: 0 blocks, 0 lines

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
@@ -63,7 +63,7 @@
 - Not a writing mode by default: do not write a lineage page unless the user
   explicitly asks for a saved artifact after seeing the read-only answer.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -78,7 +78,7 @@
 
 ## Phases
 
-### Phase 1: Resolve the idea target
+### Phase 1: Resolve the idea target (( inert, role: procedure ))
 
 1. Restate the idea in one sentence.
 2. Search for exact phrase variants with `search`.
@@ -91,7 +91,7 @@
 If multiple distinct ideas share the same phrase, ask the user to choose the
 intended one before synthesizing.
 
-### Phase 2: Gather evidence
+### Phase 2: Gather evidence (( inert, role: procedure ))
 
 Collect enough evidence to support or reject each output bucket:
 
@@ -110,7 +110,7 @@
 Prefer fewer high-quality sources over a long unsorted pile. Read full pages
 when snippets imply a lineage milestone.
 
-### Phase 3: Classify lineage moments
+### Phase 3: Classify lineage moments (( inert, role: procedure ))
 
 Classify evidence into these buckets:
 
@@ -131,13 +131,13 @@
 When a bucket has no evidence, write "No clear evidence found" with a brief note
 about what was checked.
 
-### Phase 4: Synthesize the lineage
+### Phase 4: Synthesize the lineage (( inert, role: procedure ))
 
 Write the answer in the output format below. Keep the synthesis proportional to
 the evidence. Do not overfit a smooth evolution if the evidence is sparse,
 messy, or contradictory.
 
-### Phase 5: Suggest optional next action
+### Phase 5: Suggest optional next action (( inert, role: procedure ))
 
 If useful, offer one concrete follow-up:
 
@@ -154,32 +154,32 @@
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
@@ -192,7 +192,7 @@
   undated page, or a fuzzy semantic match.
 - Preserve source ids in citations when search or page payloads include them.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Running `concept-synthesis` for a single-idea question.
 - Presenting an entity's MRR, ARR, role, or status trajectory as conceptual
@@ -203,7 +203,7 @@
 - Using real names, companies, funds, or fork-specific examples in bundled
   fixtures or documentation.
 
-## Related Skills and Operations
+## Related Skills and Operations (( inert ))
 
 - `skills/concept-synthesis/SKILL.md` - broad mutating concept-map synthesis.
 - `skills/query/SKILL.md` - general brain search and cited answers.
@@ -211,7 +211,7 @@
 - `find_trajectory` - structured typed-fact and event timelines for entities.
 - `find_contradictions` - cached suspected contradiction findings.
 
-## Tools Used
+## Tools Used (( inert ))
 
 - `search` - keyword search for exact phrase variants and dated mentions.
 - `query` - semantic search for conceptual matches.
```
