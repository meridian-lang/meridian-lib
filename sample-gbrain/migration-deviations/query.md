# Deviation: query.meri

- Original: `query/SKILL.md`
- Ported: `query.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 156 -> 162 (+37 / -31)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 8/12 inert (67% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=1, tools-metadata=1
- Judgment: 1 blocks, 5 lines

### Inert section details
- L43 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L51 `Quality Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L60 `Token-Budget Awareness`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L72 `Source precedence`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L84 `Citation in Answers`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L92 `Graph Traversal (v0.10.1+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L114 `Search Quality Awareness`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L123 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/query/SKILL.md
+++ skills/query.meri
@@ -31,38 +31,44 @@
 
 # Query Skill
 
-Answer questions using the brain's knowledge with 3-layer search and synthesis.
+> Answer questions using the brain's knowledge with 3-layer search and synthesis.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Every answer is grounded in brain content (no hallucination)
-- Every claim has a citation tracing back to a specific page slug
-- Gaps are flagged explicitly ("the brain doesn't have information on X")
-- Source precedence is respected (user statements > compiled truth > timeline > external)
-- Conflicting sources are noted with both citations
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Every answer is grounded in brain content (no hallucination)
+- [ ] Every claim has a citation tracing back to a specific page slug
+- [ ] Gaps are flagged explicitly ("the brain doesn't have information on X")
+- [ ] Source precedence is respected (user statements > compiled truth > timeline > external)
+- [ ] Conflicting sources are noted with both citations
 
 ## Phases
 
-1. **Decompose the question** into search strategies:
-   - Keyword search for specific names, dates, terms
-   - Semantic query for conceptual questions
-   - Structured queries (list by type, backlinks) for relational questions
-2. **Execute searches:**
-   - Keyword search gbrain for FTS matches (search)
-   - Hybrid search gbrain for semantic+keyword with expansion (query)
-   - List pages in gbrain by type or check backlinks for structural queries
-3. **Read top results.** Read the top 3-5 pages from gbrain to get full context.
-4. **Synthesize answer** with citations. Every claim traces back to a specific page slug.
-5. **Flag gaps.** If the brain doesn't have info, say "the brain doesn't have information on X" rather than hallucinating.
+use judgment to answer the question from the brain with citations:
+  Decompose the question into keyword, semantic, and structured search strategies.
+  Execute keyword search, hybrid query, and structural list or backlink lookups.
+  Read the top results to gather full context.
+  Synthesize an answer where every claim cites a specific page slug.
+  Flag gaps explicitly when the brain lacks the information.
 
-## Anti-Patterns
+## Coverage guard
 
-- Answering from general knowledge when the brain has relevant content
-- Hallucinating facts not in the brain
-- Silently picking one source when sources conflict
-- Loading full pages when search chunks are sufficient
-- Ignoring source precedence (user statements are highest authority)
+> If the indexed landing page is empty, the brain has a coverage gap; flag it
+> rather than answering from general knowledge.
+
+bind page = invoke get page with slug = "index".
+if the page is unwritten,
+  emit query.gap with status "no coverage".
+
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Answering from general knowledge when the brain has relevant content
+- [ ] Hallucinating facts not in the brain
+- [ ] Silently picking one source when sources conflict
+- [ ] Loading full pages when search chunks are sufficient
+- [ ] Ignoring source precedence (user statements are highest authority)
 
 ## Output Format
 
@@ -72,7 +78,7 @@
 - Gap flags: "The brain doesn't have information on X"
 - Conflict notes when sources disagree
 
-## Quality Rules
+## Quality Rules (( inert ))
 
 - Never hallucinate. Only answer from brain content.
 - Cite sources: "According to concepts/do-things-that-dont-scale..."
@@ -81,7 +87,7 @@
 - For "what happened" questions, use timeline entries
 - For "what do we know" questions, read compiled_truth directly
 
-## Token-Budget Awareness
+## Token-Budget Awareness (( inert ))
 
 Search returns **chunks**, not full pages. Read the excerpts first before deciding
 whether to load a full page.
@@ -93,7 +99,7 @@
 - **"Tell me about X"** -- get the full page (the user wants the complete picture).
 - **"Did anyone mention Y?"** -- search results are enough (the user wants a yes/no with evidence).
 
-### Source precedence
+### Source precedence (( inert ))
 
 When multiple sources provide conflicting information, follow this precedence:
 
@@ -105,7 +111,7 @@
 When sources conflict, note the contradiction with both citations. Don't silently
 pick one.
 
-## Citation in Answers
+## Citation in Answers (( inert ))
 
 When referencing brain pages in your answer, propagate inline citations:
 - Cite the page: "According to [Source: people/jane-doe, compiled truth]..."
@@ -113,7 +119,7 @@
   the user can trace facts to their origin
 - When you synthesize across multiple pages, cite all sources
 
-## Graph Traversal (v0.10.1+)
+## Graph Traversal (v0.10.1+) (( inert ))
 
 For relationship questions ("who knows who at X?", "connections between A and B",
 "who works at Acme?", "who attended the standup?"), use the graph layer instead
@@ -135,7 +141,7 @@
 graph structure. Search results are ranked with a small backlink boost so well-
 connected entities surface higher.
 
-## Search Quality Awareness
+## Search Quality Awareness (( inert ))
 
 If search results seem off (wrong results, missing known pages, irrelevant hits):
 - Run `gbrain doctor --json` to check index health
```
