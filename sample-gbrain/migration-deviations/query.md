# Deviation: query.meri

- Original: `query/SKILL.md`
- Ported: `query.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 156 -> 173 (+35 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L43 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L74 `Source precedence`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L86 `Citation in Answers`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L134 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 6/11 (55% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=1, tools-metadata=1
- Judgment: 5 blocks, 0 lines

### Inert section details
- L43 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L74 `Source precedence`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L86 `Citation in Answers`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L94 `Graph Traversal (v0.10.1+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L122 `Search Quality Awareness`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L134 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/query/SKILL.md
+++ skills/query.meri
@@ -31,18 +31,23 @@
 
 # Query Skill
 
-Answer questions using the brain's knowledge with 3-layer search and synthesis.
+> Answer questions using the brain's knowledge with 3-layer search and synthesis.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
-This skill guarantees:
-- Every answer is grounded in brain content (no hallucination)
-- Every claim has a citation tracing back to a specific page slug
 - Gaps are flagged explicitly ("the brain doesn't have information on X")
 - Source precedence is respected (user statements > compiled truth > timeline > external)
 - Conflicting sources are noted with both citations
 
+
+### Contract — steps
+
+> This skill guarantees:
+- Every answer is grounded in brain content (no hallucination)
+- Every claim has a citation tracing back to a specific page slug
 ## Phases
+use judgment to follow the Phases guidance:
 
 1. **Decompose the question** into search strategies:
    - Keyword search for specific names, dates, terms
@@ -56,7 +61,8 @@
 4. **Synthesize answer** with citations. Every claim traces back to a specific page slug.
 5. **Flag gaps.** If the brain doesn't have info, say "the brain doesn't have information on X" rather than hallucinating.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Answering from general knowledge when the brain has relevant content
 - Hallucinating facts not in the brain
@@ -72,7 +78,8 @@
 - Gap flags: "The brain doesn't have information on X"
 - Conflict notes when sources disagree
 
-## Quality Rules
+## Quality Rules (( role: procedure ))
+use judgment to follow the Quality Rules guidance:
 
 - Never hallucinate. Only answer from brain content.
 - Cite sources: "According to concepts/do-things-that-dont-scale..."
@@ -82,6 +89,7 @@
 - For "what do we know" questions, read compiled_truth directly
 
 ## Token-Budget Awareness
+use judgment to follow the Token-Budget Awareness guidance:
 
 Search returns **chunks**, not full pages. Read the excerpts first before deciding
 whether to load a full page.
@@ -93,7 +101,7 @@
 - **"Tell me about X"** -- get the full page (the user wants the complete picture).
 - **"Did anyone mention Y?"** -- search results are enough (the user wants a yes/no with evidence).
 
-### Source precedence
+### Source precedence (( inert ))
 
 When multiple sources provide conflicting information, follow this precedence:
 
@@ -105,7 +113,7 @@
 When sources conflict, note the contradiction with both citations. Don't silently
 pick one.
 
-## Citation in Answers
+## Citation in Answers (( inert ))
 
 When referencing brain pages in your answer, propagate inline citations:
 - Cite the page: "According to [Source: people/jane-doe, compiled truth]..."
@@ -113,19 +121,25 @@
   the user can trace facts to their origin
 - When you synthesize across multiple pages, cite all sources
 
-## Graph Traversal (v0.10.1+)
+## Graph Traversal (v0.10.1+) (( inert ))
 
-For relationship questions ("who knows who at X?", "connections between A and B",
-"who works at Acme?", "who attended the standup?"), use the graph layer instead
-of full-text search:
+- Available link types: `attended`, `works_at`, `invested_in`, `founded`, `advises`, `mentions`, `source`
+
+### Graph Traversal (v0.10.1+) — steps
+
+> For relationship questions ("who knows who at X?", "connections between A and B",
+> "who works at Acme?", "who attended the standup?"), use the graph layer instead
+> of full-text search:
 
 - `gbrain graph-query <slug> --type <link_type> --depth N --direction in|out|both`
-- Available link types: `attended`, `works_at`, `invested_in`, `founded`, `advises`, `mentions`, `source`
+
+### Graph Traversal (v0.10.1+) — steps 2
+
 - `--direction in` answers "who points to X?" (e.g., who works at company X)
 - `--direction out` answers "what does X point to?" (default)
 - `--depth N` controls multi-hop traversal (default 5)
 
-Examples:
+> Examples:
 - "Who works at Acme?" → `gbrain graph-query companies/acme --type works_at --direction in`
 - "Who attended Demo Day W26?" → `gbrain graph-query meetings/demo-day-w26 --type attended --direction out`
 - "What companies has Emily advised?" → `gbrain graph-query people/emily --type advises --direction out`
@@ -135,15 +149,18 @@
 graph structure. Search results are ranked with a small backlink boost so well-
 connected entities surface higher.
 
-## Search Quality Awareness
+## Search Quality Awareness (( inert ))
 
-If search results seem off (wrong results, missing known pages, irrelevant hits):
-- Run `gbrain doctor --json` to check index health
 - Check embedding coverage -- partial embeddings degrade hybrid search
 - Compare keyword search (`gbrain search`) vs hybrid search (`gbrain query`)
   for the same query to isolate whether the issue is embedding-related
 - Report search quality issues in the maintain workflow (see maintain skill)
 
+
+### Search Quality Awareness — steps
+
+> If search results seem off (wrong results, missing known pages, irrelevant hits):
+- Run `gbrain doctor --json` to check index health
 ## Tools Used
 
 - Keyword search gbrain (search)
```
