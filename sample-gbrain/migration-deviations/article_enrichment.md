# Deviation: article_enrichment.meri

- Original: `article-enrichment/SKILL.md`
- Ported: `article_enrichment.meri`
- Tier: 2 (light edits)
- Similarity: 61%
- Lines: 150 -> 152 (+60 / -58)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 6/11 inert (55% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=5, template=1
- Judgment: 3 blocks, 28 lines

### Inert section details
- L12 `What this does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L37 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L73 `Quality bar`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L95 `Link convention`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L113 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L132 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/article-enrichment/SKILL.md
+++ skills/article_enrichment.meri
@@ -26,7 +26,7 @@
 > personalized one-of-one synthesis output uses the sanctioned
 > `media/articles/<slug>-personalized.md` exception.
 
-## What this does
+## What this does (( inert ))
 
 Takes an article brain page that's a wall of raw extracted text and rewrites
 it as a structured page with:
@@ -42,16 +42,16 @@
 Raw source content is preserved in a collapsed `<details>` section so the
 original is never lost.
 
-## When to invoke
+## When to invoke (( role: procedure ))
 
-- New article page lands in the brain via media-ingest with `needs_enrichment: true`
-- Existing article page is a wall of text under a `## Content` header with
-  no synthesis
-- User says a brain page is useless, boring, or a dump
-- An LLM-judge brain-quality eval fails on quotability or actionability for
-  an article page
-
-## The pipeline
+use judgment to follow the When to invoke guidance:
+  item: New article page lands in the brain via media-ingest with `needs_enrichment: true`
+  item: Existing article page is a wall of text under a `## Content` header with
+    no synthesis
+  item: User says a brain page is useless, boring, or a dump
+  item: An LLM-judge brain-quality eval fails on quotability or actionability for
+    an article page
+## The pipeline (( inert ))
 
 ```
 1. READ      → Open the article brain page; parse frontmatter + body.
@@ -64,30 +64,30 @@
                (Iron Law per conventions/quality.md).
 ```
 
-## Invocation
+## Invocation (( role: procedure ))
 
-The skill itself is markdown instructions to the agent. It does NOT ship a
-deterministic CLI command in v0.25.1. The agent uses gbrain's existing
-operations:
-
-```bash
-# 1. Find candidate pages
-gbrain query "needs_enrichment: true type:article" --limit 50
-
-# 2. For each candidate, read the page
-gbrain get media/articles/<slug>
-
-# 3. Enrich via the agent's LLM (Sonnet by default; Opus for high-value)
-#    The agent reads the raw content + brain context + writes the structured page.
-
-# 4. Write the enriched page
-#    Use the put_page operation with the new structured markdown body.
-
-# 5. Cross-link entities
-#    For every person/company mentioned, add a timeline back-link.
-```
-
-## Quality bar
+use judgment to follow the Invocation guidance:
+  The skill itself is markdown instructions to the agent. It does NOT ship a
+  deterministic CLI command in v0.25.1. The agent uses gbrain's existing
+  operations:
+  
+  ```bash
+  # 1. Find candidate pages
+  gbrain query "needs_enrichment: true type:article" --limit 50
+  
+  # 2. For each candidate, read the page
+  gbrain get media/articles/<slug>
+  
+  # 3. Enrich via the agent's LLM (Sonnet by default; Opus for high-value)
+  #    The agent reads the raw content + brain context + writes the structured page.
+  
+  # 4. Write the enriched page
+  #    Use the put_page operation with the new structured markdown body.
+  
+  # 5. Cross-link entities
+  #    For every person/company mentioned, add a timeline back-link.
+  ```
+## Quality bar (( inert ))
 
 An enriched page passes if it has:
 
@@ -98,51 +98,53 @@
 - ✅ `## See Also` with standard markdown links (NOT `[[wiki-links]]`)
 - ✅ `<details>` block preserving the raw source content
 
-## Model selection
+## Model selection (( role: procedure ))
 
-| Model | Use when | Quote accuracy |
-|-------|----------|----------------|
-| **Sonnet** (default) | Bulk enrichment, most articles | Good — occasionally paraphrases |
-| **Opus** | High-value content, original-thinking pieces, longreads | Excellent — respects "verbatim" instruction |
-
-Rule: for bulk enrichment, do a Sonnet draft pass and spot-check 5 with
-the LLM-judge brain-quality eval. If quotes are paraphrased, switch to
-Opus for that batch.
-
-## Link convention
+use judgment to follow the Model selection guidance:
+  | Model | Use when | Quote accuracy |
+  |-------|----------|----------------|
+  | **Sonnet** (default) | Bulk enrichment, most articles | Good — occasionally paraphrases |
+  | **Opus** | High-value content, original-thinking pieces, longreads | Excellent — respects "verbatim" instruction |
+  
+  Rule: for bulk enrichment, do a Sonnet draft pass and spot-check 5 with
+  the LLM-judge brain-quality eval. If quotes are paraphrased, switch to
+  Opus for that batch.
+## Link convention (( inert ))
 
 All cross-references use standard markdown links: `[Title](relative/path.md)`.
 NEVER use `[[wiki-links]]` — they don't render on GitHub.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- ❌ Paraphrasing quotes ("the author argues that…"). Quotes are verbatim
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Paraphrasing quotes ("the author argues that…"). Quotes are verbatim
   or they're not quotes.
-- ❌ Generic "Why It Matters" ("this is important because innovation").
+- [ ] ❌ Generic "Why It Matters" ("this is important because innovation").
   Tie to specific brain context or remove the section.
-- ❌ Inventing topic labels and calling them insights. An insight is a
+- [ ] ❌ Inventing topic labels and calling them insights. An insight is a
   thing the article says that you didn't already know.
-- ❌ Discarding the raw source. Always wrap it in `<details>`.
-- ❌ Re-enriching non-idempotently — check the `needs_enrichment` flag in
+- [ ] ❌ Discarding the raw source. Always wrap it in `<details>`.
+- [ ] ❌ Re-enriching non-idempotently — check the `needs_enrichment` flag in
   frontmatter; skip if already false.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/media-ingest/SKILL.md` — creates the raw article pages this skill enriches
 - `skills/idea-ingest/SKILL.md` — link/article ingestion with author people-page enforcement
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
+> This skill guarantees:
 
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+!!! checklist (( ai-autonomy ))
+- [ ] Routing matches the canonical triggers in the frontmatter.
+- [ ] Output written under the directories listed in `writes_to:` (when applicable).
+- [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+- [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
 
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+> The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
 ## Output Format
 
```
