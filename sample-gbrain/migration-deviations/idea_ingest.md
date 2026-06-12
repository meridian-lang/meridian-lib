# Deviation: idea_ingest.meri

- Original: `idea-ingest/SKILL.md`
- Ported: `idea_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 105 -> 95 (+17 / -27)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 3/4 inert (75% inert ratio)
- Judgment: 1 blocks, 4 lines

## Unified diff

```diff
--- original-skills/idea-ingest/SKILL.md
+++ skills/idea_ingest.meri
@@ -31,7 +31,7 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every ingested item has a brain page with genuine analysis (not just a summary)
@@ -48,29 +48,19 @@
 
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
 
@@ -82,20 +72,20 @@
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
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Just summarizing without connecting to brain knowledge
 - Filing everything in `sources/` (sources is for raw data dumps only)
```
