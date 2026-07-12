# Deviation: article_enrichment.meri

- Original: `article-enrichment/SKILL.md`
- Ported: `article_enrichment.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 150 -> 176 (+45 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L44 `The pipeline`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L145 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L156 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 106 non-blank ported lines
- Sections inert total: 8/9 (89% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=7, template=1
- Judgment: 2 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=1, meaning=111

### Inert section details
- L12 `What this does`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L31 `When to invoke`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `The pipeline`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `Quality bar`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L115 `Link convention`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L123 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L145 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L156 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/article-enrichment/SKILL.md
+++ skills/article_enrichment.meri
@@ -26,7 +26,7 @@
 > personalized one-of-one synthesis output uses the sanctioned
 > `media/articles/<slug>-personalized.md` exception.
 
-## What this does
+## What this does (( role: reference ))
 
 Takes an article brain page that's a wall of raw extracted text and rewrites
 it as a structured page with:
@@ -39,19 +39,26 @@
 - **Surprising or Counterintuitive** — what makes this content unique
 - **See Also** — standard markdown links to related brain pages
 
+
+### What this does — steps (( role: reference ))
+
 Raw source content is preserved in a collapsed `<details>` section so the
 original is never lost.
 
-## When to invoke
+## When to invoke (( role: reference ))
 
 - New article page lands in the brain via media-ingest with `needs_enrichment: true`
 - Existing article page is a wall of text under a `## Content` header with
   no synthesis
 - User says a brain page is useless, boring, or a dump
+
+### When to invoke — steps
+
+use judgment to follow the When to invoke — steps guidance:
 - An LLM-judge brain-quality eval fails on quotability or actionability for
   an article page
 
-## The pipeline
+## The pipeline (( role: reference ))
 
 ```
 1. READ      → Open the article brain page; parse frontmatter + body.
@@ -66,9 +73,12 @@
 
 ## Invocation
 
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
@@ -87,34 +97,47 @@
 #    For every person/company mentioned, add a timeline back-link.
 ```
 
-## Quality bar
+## Quality bar (( role: reference ))
 
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
+## Model selection
 
-## Model selection
+
+### Model selection — steps
 
 | Model | Use when | Quote accuracy |
 |-------|----------|----------------|
-| **Sonnet** (default) | Bulk enrichment, most articles | Good — occasionally paraphrases |
-| **Opus** | High-value content, original-thinking pieces, longreads | Excellent — respects "verbatim" instruction |
+| Sonnet (default) | Bulk enrichment, most articles | Good — occasionally paraphrases |
+| Opus | High-value content, original-thinking pieces, longreads | Excellent — respects "verbatim" instruction |
 
+
+### Model selection — steps 2
+
+use judgment to follow the Model selection — steps 2 guidance:
 Rule: for bulk enrichment, do a Sonnet draft pass and spot-check 5 with
 the LLM-judge brain-quality eval. If quotes are paraphrased, switch to
 Opus for that batch.
 
-## Link convention
+## Link convention (( role: reference ))
 
 All cross-references use standard markdown links: `[Title](relative/path.md)`.
+
+### Link convention — steps
+
 NEVER use `[[wiki-links]]` — they don't render on GitHub.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Paraphrasing quotes ("the author argues that…"). Quotes are verbatim
   or they're not quotes.
@@ -122,10 +145,13 @@
   Tie to specific brain context or remove the section.
 - ❌ Inventing topic labels and calling them insights. An insight is a
   thing the article says that you didn't already know.
-- ❌ Discarding the raw source. Always wrap it in `<details>`.
 - ❌ Re-enriching non-idempotently — check the `needs_enrichment` flag in
   frontmatter; skip if already false.
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+- ❌ Discarding the raw source. Always wrap it in `<details>`.
 ## Related skills
 
 - `skills/media-ingest/SKILL.md` — creates the raw article pages this skill enriches
@@ -133,7 +159,7 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -144,7 +170,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
