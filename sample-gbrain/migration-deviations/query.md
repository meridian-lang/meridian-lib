# Deviation: query.meri

- Original: `query/SKILL.md`
- Ported: `query.meri`
- Tier: 2 (light edits)
- Similarity: 71%
- Lines: 156 -> 198 (+72 / -30)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L36 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L159 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 11/11 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=9, template=1, tools-metadata=1
- Judgment: 3 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=123

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L18 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L36 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L52 `Quality Rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L64 `Token-Budget Awareness`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `Source precedence`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L105 `Citation in Answers`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L119 `Graph Traversal (v0.10.1+)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L147 `Search Quality Awareness`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L159 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/query/SKILL.md
+++ skills/query.meri
@@ -31,18 +31,21 @@
 
 # Query Skill
 
-Answer questions using the brain's knowledge with 3-layer search and synthesis.
+> Answer questions using the brain's knowledge with 3-layer search and synthesis.
 
-## Contract
+## Contract (( role: reference ))
 
-This skill guarantees:
-- Every answer is grounded in brain content (no hallucination)
-- Every claim has a citation tracing back to a specific page slug
 - Gaps are flagged explicitly ("the brain doesn't have information on X")
 - Source precedence is respected (user statements > compiled truth > timeline > external)
 - Conflicting sources are noted with both citations
 
-## Phases
+
+### Contract — steps
+
+> This skill guarantees:
+- Every answer is grounded in brain content (no hallucination)
+- Every claim has a citation tracing back to a specific page slug
+## Phases (( role: reference ))
 
 1. **Decompose the question** into search strategies:
    - Keyword search for specific names, dates, terms
@@ -53,10 +56,14 @@
    - Hybrid search gbrain for semantic+keyword with expansion (query)
    - List pages in gbrain by type or check backlinks for structural queries
 3. **Read top results.** Read the top 3-5 pages from gbrain to get full context.
-4. **Synthesize answer** with citations. Every claim traces back to a specific page slug.
 5. **Flag gaps.** If the brain doesn't have info, say "the brain doesn't have information on X" rather than hallucinating.
 
-## Anti-Patterns
+
+### Phases — steps
+
+use judgment to follow the Phases — steps guidance:
+4. **Synthesize answer** with citations. Every claim traces back to a specific page slug.
+## Anti-Patterns (( role: reference ))
 
 - Answering from general knowledge when the brain has relevant content
 - Hallucinating facts not in the brain
@@ -72,60 +79,92 @@
 - Gap flags: "The brain doesn't have information on X"
 - Conflict notes when sources disagree
 
-## Quality Rules
+## Quality Rules (( role: reference ))
 
-- Never hallucinate. Only answer from brain content.
 - Cite sources: "According to concepts/do-things-that-dont-scale..."
 - Flag stale results: if a search result shows [STALE], note that the info may be outdated
 - For "who" questions, use backlinks and typed links to find connections
 - For "what happened" questions, use timeline entries
 - For "what do we know" questions, read compiled_truth directly
 
-## Token-Budget Awareness
 
+### Quality Rules — steps (( role: reference ))
+
+- Never hallucinate. Only answer from brain content.
+## Token-Budget Awareness (( role: reference ))
+
+- `gbrain search` / `gbrain query` return ranked chunks with context snippets.
+  These are often enough to answer the question directly.
+- **"Tell me about X"** -- get the full page (the user wants the complete picture).
+- **"Did anyone mention Y?"** -- search results are enough (the user wants a yes/no with evidence).
+
+
+### Token-Budget Awareness — steps
+
+use judgment to follow the Token-Budget Awareness — steps guidance:
 Search returns **chunks**, not full pages. Read the excerpts first before deciding
 whether to load a full page.
 
-- `gbrain search` / `gbrain query` return ranked chunks with context snippets.
-  These are often enough to answer the question directly.
+
+### Token-Budget Awareness — steps 2
+
 - Only use `gbrain get <slug>` to load the full page when a chunk confirms the
   page is relevant and you need more context (e.g., compiled truth, timeline).
-- **"Tell me about X"** -- get the full page (the user wants the complete picture).
-- **"Did anyone mention Y?"** -- search results are enough (the user wants a yes/no with evidence).
+### Source precedence (( role: reference ))
 
-### Source precedence
+1. **User's direct statements** (highest authority -- what the user told you directly)
+3. **Timeline entries** (raw evidence, reverse-chronological)
+4. **External sources** (web search, API enrichment -- lowest authority)
+
+
+### Source precedence — steps (( role: reference ))
 
 When multiple sources provide conflicting information, follow this precedence:
 
-1. **User's direct statements** (highest authority -- what the user told you directly)
+
+### Source precedence — steps 2
+
+use judgment to follow the Source precedence — steps 2 guidance:
 2. **Compiled truth** (the brain's synthesized, cited understanding)
-3. **Timeline entries** (raw evidence, reverse-chronological)
-4. **External sources** (web search, API enrichment -- lowest authority)
+
+### Source precedence — steps 3 (( role: reference ))
 
 When sources conflict, note the contradiction with both citations. Don't silently
 pick one.
 
-## Citation in Answers
+## Citation in Answers (( role: reference ))
+
+- Cite the page: "According to [Source: people/jane-doe, compiled truth]..."
+
+### Citation in Answers — steps (( role: reference ))
 
 When referencing brain pages in your answer, propagate inline citations:
-- Cite the page: "According to [Source: people/jane-doe, compiled truth]..."
+
+### Citation in Answers — steps 2 (( role: reference ))
+
 - When brain pages have inline `[Source: ...]` citations, propagate them so
   the user can trace facts to their origin
 - When you synthesize across multiple pages, cite all sources
 
-## Graph Traversal (v0.10.1+)
+## Graph Traversal (v0.10.1+) (( role: reference ))
 
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
@@ -135,15 +174,18 @@
 graph structure. Search results are ranked with a small backlink boost so well-
 connected entities surface higher.
 
-## Search Quality Awareness
+## Search Quality Awareness (( role: reference ))
 
-If search results seem off (wrong results, missing known pages, irrelevant hits):
-- Run `gbrain doctor --json` to check index health
 - Check embedding coverage -- partial embeddings degrade hybrid search
 - Compare keyword search (`gbrain search`) vs hybrid search (`gbrain query`)
   for the same query to isolate whether the issue is embedding-related
 - Report search quality issues in the maintain workflow (see maintain skill)
 
+
+### Search Quality Awareness — steps
+
+If search results seem off (wrong results, missing known pages, irrelevant hits):
+- Run `gbrain doctor --json` to check index health
 ## Tools Used
 
 - Keyword search gbrain (search)
```
