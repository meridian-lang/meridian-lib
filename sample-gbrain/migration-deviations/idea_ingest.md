# Deviation: idea_ingest.meri

- Original: `idea-ingest/SKILL.md`
- Ported: `idea_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 105 -> 120 (+27 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L61 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L61 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/idea-ingest/SKILL.md
+++ skills/idea_ingest.meri
@@ -31,7 +31,8 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Every ingested item has a brain page with genuine analysis (not just a summary)
@@ -47,22 +48,14 @@
 Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
 
 ## Phases
+use judgment to follow the Phases guidance:
 
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
@@ -70,7 +63,28 @@
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
 
@@ -95,7 +109,8 @@
 {How this connects to existing brain knowledge. What's new. What contradicts.}
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Just summarizing without connecting to brain knowledge
 - Filing everything in `sources/` (sources is for raw data dumps only)
```
