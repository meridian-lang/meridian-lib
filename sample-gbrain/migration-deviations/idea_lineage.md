# Deviation: idea_lineage.meri

- Original: `idea-lineage/SKILL.md`
- Ported: `idea_lineage.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 223 -> 223 (+21 / -21)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 14/14 inert (100% inert ratio)
- Operational inert: 8
- Unclassified inert: 0
- Inert categories: normative-contract=2, operational-procedure=6, reference-documentation=4, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L11 `What this solves`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L28 `What this is not`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L39 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L52 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L54 `Phase 1: Resolve the idea target`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L67 `Phase 2: Gather evidence`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L86 `Phase 3: Classify lineage moments`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L107 `Phase 4: Synthesize the lineage`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L113 `Phase 5: Suggest optional next action`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L125 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L155 `Quality Rules`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L168 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L179 `Related Skills and Operations`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L187 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
 
@@ -76,9 +76,9 @@
   temporal evolution.
 - The default mode is read-only and does not mutate brain pages.
 
-## Phases
-
-### Phase 1: Resolve the idea target
+## Phases (( inert, role: procedure ))
+
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
 
@@ -149,37 +149,37 @@
 - Run a contradiction probe only when stale cached findings are insufficient
   and the user explicitly wants that heavier pass.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
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
+## Quality Rules (( inert, role: invariants ))
 
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
+## Tools Used (( inert, role: tools ))
 
 - `search` - keyword search for exact phrase variants and dated mentions.
 - `query` - semantic search for conceptual matches.
```
