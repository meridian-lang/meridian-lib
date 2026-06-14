# Deviation: idea_ingest.meri

- Original: `idea-ingest/SKILL.md`
- Ported: `idea_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 62%
- Lines: 105 -> 97 (+34 / -42)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 1/4 inert (25% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 1 blocks, 4 lines

### Inert section details
- L38 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/idea-ingest/SKILL.md
+++ skills/idea_ingest.meri
@@ -31,46 +31,37 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Every ingested item has a brain page with genuine analysis (not just a summary)
-- The author gets a people page (MANDATORY for anyone whose thinking is worth ingesting)
-- Cross-links created bidirectionally (source ↔ author, source ↔ mentioned entities)
-- Raw source preserved for provenance via `gbrain files upload-raw`
-- Every fact has an inline `[Source: ...]` citation
-- Filing follows primary subject rules (not format-based)
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Every ingested item has a brain page with genuine analysis (not just a summary)
+- [ ] The author gets a people page (MANDATORY for anyone whose thinking is worth ingesting)
+- [ ] Cross-links created bidirectionally (source ↔ author, source ↔ mentioned entities)
+- [ ] Raw source preserved for provenance via `gbrain files upload-raw`
+- [ ] Every fact has an inline `[Source: ...]` citation
+- [ ] Filing follows primary subject rules (not format-based)
 
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+> > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
-Every mention of a person or company with a brain page MUST create a back-link.
-Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
+> Every mention of a person or company with a brain page MUST create a back-link.
+> Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
 
 ## Phases
 
-1. **Fetch the content.** Use appropriate tools for the content type (web fetch for articles, API for tweets, PDF reader for documents).
+```bash
+gbrain files upload-raw <file> --page <slug>
+```
 
-2. **Upload raw source.** Save the fetched content for provenance: `gbrain files upload-raw <file> --page <slug>`
+use judgment to ingest the idea source and connect the content to the brain:
+  Fetch the content with the appropriate tool for its type (web fetch, API, or PDF reader).
+  Identify the author and create or update their people page, cross-linking both directions.
+  Save the page filed by primary subject (person, company, concept, or raw source).
+  Analyze the content against what the brain knows: active projects, contradictions, and connections.
 
-3. **Identify the author — MANDATORY people page.** Anyone whose thinking is worth ingesting is worth tracking.
-   - Search brain for existing author page
-   - If no page → CREATE ONE with compiled truth + timeline format
-   - If page exists → update timeline with this new publication
-   - Cross-link both directions
-
-4. **Save to brain.** File by PRIMARY SUBJECT (read `skills/_brain-filing-rules.md`):
-   - About a person → `people/`
-   - About a company → `companies/`
-   - A reusable framework → `concepts/`
-   - Raw data dump → `sources/`
-
-5. **Analyze for the user.** Reply with analysis that connects the content to what the brain knows. Think about:
-   - Active projects — is this relevant?
-   - Contradictions — does this challenge existing brain knowledge?
-   - Connections — does this involve known people/companies?
-   - Don't just summarize. Tell the user things they wouldn't have noticed.
-
-6. **Sync.** `gbrain sync` to update the index.
+```bash
+gbrain sync
+```
 
 ## Output Format
 
@@ -82,24 +73,25 @@
 **Published:** {date}
 **Ingested:** {date}
 
-## Context
+## Context (( inert ))
 {Why this matters now, connected to brain knowledge}
 
-## Summary
+## Summary (( inert ))
 {3-5 bullet core arguments}
 
-## Key Data / Claims
+## Key Data / Claims (( inert ))
 {Specific facts, numbers, quotes}
 
-## Analysis
+## Analysis (( inert ))
 {How this connects to existing brain knowledge. What's new. What contradicts.}
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Just summarizing without connecting to brain knowledge
-- Filing everything in `sources/` (sources is for raw data dumps only)
-- Skipping the author people page
-- Not cross-linking to mentioned entities
-- Ingesting without checking brain first for existing coverage
+!!! checklist (( ai-autonomy ))
+- [ ] Just summarizing without connecting to brain knowledge
+- [ ] Filing everything in `sources/` (sources is for raw data dumps only)
+- [ ] Skipping the author people page
+- [ ] Not cross-linking to mentioned entities
+- [ ] Ingesting without checking brain first for existing coverage
 
```
