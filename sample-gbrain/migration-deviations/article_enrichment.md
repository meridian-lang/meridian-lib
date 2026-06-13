# Deviation: article_enrichment.meri

- Original: `article-enrichment/SKILL.md`
- Ported: `article_enrichment.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 150 -> 150 (+10 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 11/11 inert (100% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/article-enrichment/SKILL.md
+++ article_enrichment.meri
@@ -26,7 +26,7 @@
 > personalized one-of-one synthesis output uses the sanctioned
 > `media/articles/<slug>-personalized.md` exception.
 
-## What this does
+## What this does (( inert ))
 
 Takes an article brain page that's a wall of raw extracted text and rewrites
 it as a structured page with:
@@ -42,7 +42,7 @@
 Raw source content is preserved in a collapsed `<details>` section so the
 original is never lost.
 
-## When to invoke
+## When to invoke (( inert, role: applicability ))
 
 - New article page lands in the brain via media-ingest with `needs_enrichment: true`
 - Existing article page is a wall of text under a `## Content` header with
@@ -51,7 +51,7 @@
 - An LLM-judge brain-quality eval fails on quotability or actionability for
   an article page
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 1. READ      → Open the article brain page; parse frontmatter + body.
@@ -64,7 +64,7 @@
                (Iron Law per conventions/quality.md).
 ```
 
-## Invocation
+## Invocation (( inert ))
 
 The skill itself is markdown instructions to the agent. It does NOT ship a
 deterministic CLI command in v0.25.1. The agent uses gbrain's existing
@@ -87,7 +87,7 @@
 #    For every person/company mentioned, add a timeline back-link.
 ```
 
-## Quality bar
+## Quality bar (( inert ))
 
 An enriched page passes if it has:
 
@@ -98,7 +98,7 @@
 - ✅ `## See Also` with standard markdown links (NOT `[[wiki-links]]`)
 - ✅ `<details>` block preserving the raw source content
 
-## Model selection
+## Model selection (( inert ))
 
 | Model | Use when | Quote accuracy |
 |-------|----------|----------------|
@@ -109,12 +109,12 @@
 the LLM-judge brain-quality eval. If quotes are paraphrased, switch to
 Opus for that batch.
 
-## Link convention
+## Link convention (( inert ))
 
 All cross-references use standard markdown links: `[Title](relative/path.md)`.
 NEVER use `[[wiki-links]]` — they don't render on GitHub.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Paraphrasing quotes ("the author argues that…"). Quotes are verbatim
   or they're not quotes.
@@ -126,14 +126,14 @@
 - ❌ Re-enriching non-idempotently — check the `needs_enrichment` flag in
   frontmatter; skip if already false.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/media-ingest/SKILL.md` — creates the raw article pages this skill enriches
 - `skills/idea-ingest/SKILL.md` — link/article ingestion with author people-page enforcement
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
```
