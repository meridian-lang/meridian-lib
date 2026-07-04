# Deviation: idea_ingest.meri

- Original: `idea-ingest/SKILL.md`
- Ported: `idea_ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 105 -> 105 (+7 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L21 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L47 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L70 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 4/4 inert (100% inert ratio)
- Operational inert: 1
- Unclassified inert: 0
- Inert categories: operational-procedure=1, reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L21 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L47 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L70 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

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
@@ -46,7 +46,7 @@
 Every mention of a person or company with a brain page MUST create a back-link.
 Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Fetch the content.** Use appropriate tools for the content type (web fetch for articles, API for tweets, PDF reader for documents).
 
@@ -82,20 +82,20 @@
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
