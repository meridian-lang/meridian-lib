# Deviation: article_enrichment.meri

- Original: `article-enrichment/SKILL.md`
- Ported: `article_enrichment.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 150 -> 167 (+39 / -22)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L39 `The pipeline`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L147 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 5/10 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=1
- Judgment: 4 blocks, 0 lines

### Inert section details
- L39 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L78 `Quality bar`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L92 `Model selection`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L107 `Link convention`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L147 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/article-enrichment/SKILL.md
+++ skills/article_enrichment.meri
@@ -27,6 +27,7 @@
 > `media/articles/<slug>-personalized.md` exception.
 
 ## What this does
+use judgment to follow the What this does guidance:
 
 Takes an article brain page that's a wall of raw extracted text and rewrites
 it as a structured page with:
@@ -42,7 +43,8 @@
 Raw source content is preserved in a collapsed `<details>` section so the
 original is never lost.
 
-## When to invoke
+## When to invoke (( role: procedure ))
+use judgment to follow the When to invoke guidance:
 
 - New article page lands in the brain via media-ingest with `needs_enrichment: true`
 - Existing article page is a wall of text under a `## Content` header with
@@ -51,7 +53,7 @@
 - An LLM-judge brain-quality eval fails on quotability or actionability for
   an article page
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 1. READ      → Open the article brain page; parse frontmatter + body.
@@ -64,11 +66,14 @@
                (Iron Law per conventions/quality.md).
 ```
 
-## Invocation
+## Invocation (( inert ))
 
-The skill itself is markdown instructions to the agent. It does NOT ship a
-deterministic CLI command in v0.25.1. The agent uses gbrain's existing
-operations:
+
+### Invocation — steps
+
+> The skill itself is markdown instructions to the agent. It does NOT ship a
+> deterministic CLI command in v0.25.1. The agent uses gbrain's existing
+> operations:
 
 ```bash
 # 1. Find candidate pages
@@ -87,34 +92,45 @@
 #    For every person/company mentioned, add a timeline back-link.
 ```
 
-## Quality bar
+## Quality bar (( inert ))
 
-An enriched page passes if it has:
+- ✅ `## Why It Matters` connecting to specific brain context (not generic)
+- ✅ `## See Also` with standard markdown links (NOT `[[wiki-links]]`)
+- ✅ `<details>` block preserving the raw source content
+
+
+### Quality bar — steps
+
+> An enriched page passes if it has:
 
 - ✅ `## Executive Summary` (2-3 sentences)
 - ✅ `## Quotable Lines` with ≥3 verbatim quotes (literal quotes, not paraphrase)
 - ✅ `## Key Insights` with ≥3 bullets (insights, not topic labels)
-- ✅ `## Why It Matters` connecting to specific brain context (not generic)
-- ✅ `## See Also` with standard markdown links (NOT `[[wiki-links]]`)
-- ✅ `<details>` block preserving the raw source content
-
-## Model selection
-
-| Model | Use when | Quote accuracy |
-|-------|----------|----------------|
-| **Sonnet** (default) | Bulk enrichment, most articles | Good — occasionally paraphrases |
-| **Opus** | High-value content, original-thinking pieces, longreads | Excellent — respects "verbatim" instruction |
+## Model selection (( inert ))
 
 Rule: for bulk enrichment, do a Sonnet draft pass and spot-check 5 with
 the LLM-judge brain-quality eval. If quotes are paraphrased, switch to
 Opus for that batch.
 
-## Link convention
+
+### Model selection — steps
+
+!!! table (( ai-discretion ))
+| Model | Use when | Quote accuracy |
+|-------|----------|----------------|
+| Sonnet (default) | Bulk enrichment, most articles | Good — occasionally paraphrases |
+| Opus | High-value content, original-thinking pieces, longreads | Excellent — respects "verbatim" instruction |
+
+## Link convention (( inert ))
 
 All cross-references use standard markdown links: `[Title](relative/path.md)`.
+
+### Link convention — steps
+
 NEVER use `[[wiki-links]]` — they don't render on GitHub.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Paraphrasing quotes ("the author argues that…"). Quotes are verbatim
   or they're not quotes.
@@ -133,7 +149,8 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -144,7 +161,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
