# Deviation: idea_ingest.meri

- Original: `idea-ingest/SKILL.md`
- Ported: `idea_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 105 -> 126 (+37 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L68 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L91 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 4/4 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=75

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L91 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/idea-ingest/SKILL.md
+++ skills/idea_ingest.meri
@@ -31,38 +31,38 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Every ingested item has a brain page with genuine analysis (not just a summary)
-- The author gets a people page (MANDATORY for anyone whose thinking is worth ingesting)
 - Cross-links created bidirectionally (source ↔ author, source ↔ mentioned entities)
 - Raw source preserved for provenance via `gbrain files upload-raw`
-- Every fact has an inline `[Source: ...]` citation
 - Filing follows primary subject rules (not format-based)
 
 > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
-Every mention of a person or company with a brain page MUST create a back-link.
 Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
 
-## Phases
+
+### Contract — steps (( role: reference ))
+
+- The author gets a people page (MANDATORY for anyone whose thinking is worth ingesting)
+
+### Contract — steps 2
+
+- Every fact has an inline `[Source: ...]` citation
+
+### Contract — steps 3 (( role: reference ))
+
+Every mention of a person or company with a brain page MUST create a back-link.
+## Phases (( role: reference ))
 
 1. **Fetch the content.** Use appropriate tools for the content type (web fetch for articles, API for tweets, PDF reader for documents).
 
-2. **Upload raw source.** Save the fetched content for provenance: `gbrain files upload-raw <file> --page <slug>`
-
 3. **Identify the author — MANDATORY people page.** Anyone whose thinking is worth ingesting is worth tracking.
-   - Search brain for existing author page
    - If no page → CREATE ONE with compiled truth + timeline format
    - If page exists → update timeline with this new publication
    - Cross-link both directions
-
-4. **Save to brain.** File by PRIMARY SUBJECT (read `skills/_brain-filing-rules.md`):
-   - About a person → `people/`
-   - About a company → `companies/`
-   - A reusable framework → `concepts/`
-   - Raw data dump → `sources/`
 
 5. **Analyze for the user.** Reply with analysis that connects the content to what the brain knows. Think about:
    - Active projects — is this relevant?
@@ -70,7 +70,28 @@
    - Connections — does this involve known people/companies?
    - Don't just summarize. Tell the user things they wouldn't have noticed.
 
-6. **Sync.** `gbrain sync` to update the index.
+
+### Phases — steps
+
+2. Upload raw source. Save the fetched content for provenance: `gbrain files upload-raw <file> --page <slug>`
+
+
+### Phases — steps 2
+
+   - Search brain for existing author page
+
+### Phases — steps 3
+
+4. Save to brain. File by PRIMARY SUBJECT (read `skills/_brain-filing-rules.md`):
+   - About a person → `people/`
+   - About a company → `companies/`
+   - A reusable framework → `concepts/`
+   - Raw data dump → `sources/`
+
+
+### Phases — steps 4
+
+6. Sync. `gbrain sync` to update the index.
 
 ## Output Format
 
@@ -95,7 +116,7 @@
 {How this connects to existing brain knowledge. What's new. What contradicts.}
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Just summarizing without connecting to brain knowledge
 - Filing everything in `sources/` (sources is for raw data dumps only)
```
