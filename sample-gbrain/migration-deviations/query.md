# Deviation: query.meri

- Original: `query/SKILL.md`
- Ported: `query.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 156 -> 156 (+11 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L15 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L29 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L37 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L45 `Quality Rules`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L54 `Token-Budget Awareness`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L66 `Source precedence`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L78 `Citation in Answers`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L86 `Graph Traversal (v0.10.1+)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L108 `Search Quality Awareness`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L117 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections: 11/11 inert (100% inert ratio)
- Operational inert: 3
- Unclassified inert: 0
- Inert categories: normative-contract=2, operational-procedure=1, reference-documentation=6, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L15 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L29 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L37 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L45 `Quality Rules`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L54 `Token-Budget Awareness`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L66 `Source precedence`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L78 `Citation in Answers`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L86 `Graph Traversal (v0.10.1+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L108 `Search Quality Awareness`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L117 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/query/SKILL.md
+++ skills/query.meri
@@ -31,9 +31,9 @@
 
 # Query Skill
 
-Answer questions using the brain's knowledge with 3-layer search and synthesis.
+> Answer questions using the brain's knowledge with 3-layer search and synthesis.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every answer is grounded in brain content (no hallucination)
@@ -42,7 +42,7 @@
 - Source precedence is respected (user statements > compiled truth > timeline > external)
 - Conflicting sources are noted with both citations
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Decompose the question** into search strategies:
    - Keyword search for specific names, dates, terms
@@ -56,7 +56,7 @@
 4. **Synthesize answer** with citations. Every claim traces back to a specific page slug.
 5. **Flag gaps.** If the brain doesn't have info, say "the brain doesn't have information on X" rather than hallucinating.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Answering from general knowledge when the brain has relevant content
 - Hallucinating facts not in the brain
@@ -64,7 +64,7 @@
 - Loading full pages when search chunks are sufficient
 - Ignoring source precedence (user statements are highest authority)
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Answers should include:
 - Direct response to the question
@@ -72,7 +72,7 @@
 - Gap flags: "The brain doesn't have information on X"
 - Conflict notes when sources disagree
 
-## Quality Rules
+## Quality Rules (( inert, role: invariants ))
 
 - Never hallucinate. Only answer from brain content.
 - Cite sources: "According to concepts/do-things-that-dont-scale..."
@@ -81,7 +81,7 @@
 - For "what happened" questions, use timeline entries
 - For "what do we know" questions, read compiled_truth directly
 
-## Token-Budget Awareness
+## Token-Budget Awareness (( inert ))
 
 Search returns **chunks**, not full pages. Read the excerpts first before deciding
 whether to load a full page.
@@ -93,7 +93,7 @@
 - **"Tell me about X"** -- get the full page (the user wants the complete picture).
 - **"Did anyone mention Y?"** -- search results are enough (the user wants a yes/no with evidence).
 
-### Source precedence
+### Source precedence (( inert ))
 
 When multiple sources provide conflicting information, follow this precedence:
 
@@ -105,7 +105,7 @@
 When sources conflict, note the contradiction with both citations. Don't silently
 pick one.
 
-## Citation in Answers
+## Citation in Answers (( inert ))
 
 When referencing brain pages in your answer, propagate inline citations:
 - Cite the page: "According to [Source: people/jane-doe, compiled truth]..."
@@ -113,7 +113,7 @@
   the user can trace facts to their origin
 - When you synthesize across multiple pages, cite all sources
 
-## Graph Traversal (v0.10.1+)
+## Graph Traversal (v0.10.1+) (( inert ))
 
 For relationship questions ("who knows who at X?", "connections between A and B",
 "who works at Acme?", "who attended the standup?"), use the graph layer instead
@@ -135,7 +135,7 @@
 graph structure. Search results are ranked with a small backlink boost so well-
 connected entities surface higher.
 
-## Search Quality Awareness
+## Search Quality Awareness (( inert ))
 
 If search results seem off (wrong results, missing known pages, irrelevant hits):
 - Run `gbrain doctor --json` to check index health
```
