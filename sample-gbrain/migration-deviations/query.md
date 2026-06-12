# Deviation: query.meri

- Original: `query/SKILL.md`
- Ported: `query.meri`
- Tier: 1 (near-verbatim)
- Similarity: 85%
- Lines: 156 -> 160 (+25 / -21)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 10/12 inert (83% inert ratio)
- Judgment: 1 blocks, 5 lines

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
@@ -44,19 +44,23 @@
 
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
+## Coverage guard (( role: procedure ))
+
+> If the indexed landing page is empty, the brain has a coverage gap; flag it
+> rather than answering from general knowledge.
+
+bind page = invoke get page with slug = "index".
+if the page is unwritten,
+  emit query.gap with status "no coverage".
+
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Answering from general knowledge when the brain has relevant content
 - Hallucinating facts not in the brain
@@ -72,7 +76,7 @@
 - Gap flags: "The brain doesn't have information on X"
 - Conflict notes when sources disagree
 
-## Quality Rules
+## Quality Rules (( inert ))
 
 - Never hallucinate. Only answer from brain content.
 - Cite sources: "According to concepts/do-things-that-dont-scale..."
@@ -81,7 +85,7 @@
 - For "what happened" questions, use timeline entries
 - For "what do we know" questions, read compiled_truth directly
 
-## Token-Budget Awareness
+## Token-Budget Awareness (( inert ))
 
 Search returns **chunks**, not full pages. Read the excerpts first before deciding
 whether to load a full page.
@@ -93,7 +97,7 @@
 - **"Tell me about X"** -- get the full page (the user wants the complete picture).
 - **"Did anyone mention Y?"** -- search results are enough (the user wants a yes/no with evidence).
 
-### Source precedence
+### Source precedence (( inert ))
 
 When multiple sources provide conflicting information, follow this precedence:
 
@@ -105,7 +109,7 @@
 When sources conflict, note the contradiction with both citations. Don't silently
 pick one.
 
-## Citation in Answers
+## Citation in Answers (( inert ))
 
 When referencing brain pages in your answer, propagate inline citations:
 - Cite the page: "According to [Source: people/jane-doe, compiled truth]..."
@@ -113,7 +117,7 @@
   the user can trace facts to their origin
 - When you synthesize across multiple pages, cite all sources
 
-## Graph Traversal (v0.10.1+)
+## Graph Traversal (v0.10.1+) (( inert ))
 
 For relationship questions ("who knows who at X?", "connections between A and B",
 "who works at Acme?", "who attended the standup?"), use the graph layer instead
@@ -135,7 +139,7 @@
 graph structure. Search results are ranked with a small backlink boost so well-
 connected entities surface higher.
 
-## Search Quality Awareness
+## Search Quality Awareness (( inert ))
 
 If search results seem off (wrong results, missing known pages, irrelevant hits):
 - Run `gbrain doctor --json` to check index health
@@ -144,7 +148,7 @@
   for the same query to isolate whether the issue is embedding-related
 - Report search quality issues in the maintain workflow (see maintain skill)
 
-## Tools Used
+## Tools Used (( inert ))
 
 - Keyword search gbrain (search)
 - Hybrid search gbrain (query)
```
