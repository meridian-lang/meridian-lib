# Deviation: data_research.meri

- Original: `data-research/SKILL.md`
- Ported: `data_research.meri`
- Tier: 2 (light edits)
- Similarity: 85%
- Lines: 139 -> 142 (+23 / -20)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L7 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Phase 1: Define Research Recipe`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Phase 2: Search Sources`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Phase 3: Classify`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L61 `Phase 5: Archive Raw Sources`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Phase 6: Deduplicate`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L75 `Phase 7: Update Canonical Tracker + Backlink`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `Built-In Recipes`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L91 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L98 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 77 non-blank ported lines
- Sections inert total: 11/13 (85% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=10, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=86

### Inert section details
- L7 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Phase 1: Define Research Recipe`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L33 `Phase 2: Search Sources`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Phase 3: Classify`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Phase 4: Extract Structured Data`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L61 `Phase 5: Archive Raw Sources`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Phase 6: Deduplicate`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L75 `Phase 7: Update Canonical Tracker + Backlink`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `Built-In Recipes`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L91 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L98 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/data-research/SKILL.md
+++ skills/data_research.meri
@@ -28,14 +28,14 @@
 
 # Data Research
 
-Structured research pipeline: search sources, extract structured data,
-archive raw, deduplicate, update canonical trackers, backlink entities.
+> Structured research pipeline: search sources, extract structured data,
+> archive raw, deduplicate, update canonical trackers, backlink entities.
 
-## Contract
+## Contract (( role: reference ))
 
 One skill for any email-to-structured-data pipeline. The only differences
 between tracking investor updates, expenses, and company metrics
-are the **search queries**, **extraction schemas**, and **tracker page format**.
+are the search queries, extraction schemas, and tracker page format.
 All three use the same 7-phase pipeline with parameterized recipes.
 
 ## When to Use
@@ -47,7 +47,7 @@
 
 ## Phases
 
-### Phase 1: Define Research Recipe
+### Phase 1: Define Research Recipe (( role: reference ))
 
 Ask the user what they want to track. Either:
 - Pick a built-in recipe: investor-updates, expense-tracker, company-updates
@@ -57,46 +57,49 @@
 Recipes are YAML files at `~/.gbrain/recipes/{name}.yaml`. Use `gbrain research init`
 to scaffold a new one.
 
-### Phase 2: Search Sources
+### Phase 2: Search Sources (( role: reference ))
 
 Brain first (maybe we already have this data). Then:
-- **Email** via credential gateway: windowed queries (quarterly, monthly if truncated)
-- **Web** via search: public filings, press releases, regulatory data
-- **APIs**: any structured data source the recipe defines
-- **Attachments**: PDF extraction, HTML stripping
+- Email via credential gateway: windowed queries (quarterly, monthly if truncated)
+- Web via search: public filings, press releases, regulatory data
+- APIs: any structured data source the recipe defines
+- Attachments: PDF extraction, HTML stripping
 
-### Phase 3: Classify
+### Phase 3: Classify (( role: reference ))
 
 Deterministic first (regex patterns from recipe), LLM fallback.
 Log every LLM fallback for future regex improvement (fail-improve loop).
 Skip marketing, newsletters, noise based on recipe's classification rules.
 
-### Phase 4: Extract Structured Data
+### Phase 4: Extract Structured Data (( role: reference ))
 
 **EXTRACTION INTEGRITY RULE:**
 1. Save raw source immediately (before any extraction)
 2. Extract fields using deterministic regex first, LLM fallback
 3. When summarizing batch results: **re-read from saved files**
-4. Never trust LLM working memory after batch processing
-
 This prevents a known hallucination bug where batch-processed amounts were
 13/13 wrong from LLM working memory while saved files were correct.
 
-### Phase 5: Archive Raw Sources
+
+### Phase 4: Extract Structured Data — steps (( role: reference ))
+
+4. Never trust LLM working memory after batch processing
+
+### Phase 5: Archive Raw Sources (( role: reference ))
 
 - `put_raw_data` for email bodies, API responses
 - `file_upload` for PDF attachments, documents
 - Create `.redirect.yaml` pointers for large files in storage
 - Every tracker entry must link back to its raw source
 
-### Phase 6: Deduplicate
+### Phase 6: Deduplicate (( role: reference ))
 
 Before adding to tracker:
 - Exact match (same key fields) → skip
 - Fuzzy match (same entity + date + similar amount within tolerance) → flag for review
 - Different amount for same entity+date → add with note (could be correction)
 
-### Phase 7: Update Canonical Tracker + Backlink
+### Phase 7: Update Canonical Tracker + Backlink (( role: reference ))
 
 - Parse existing tracker page (markdown table)
 - Append new entries in correct section (grouped by year/quarter/entity)
@@ -104,7 +107,7 @@
 - Backlink every mentioned entity (person → people/ page, company → companies/ page)
 - Uses enrichment service for entity pages
 
-## Built-In Recipes
+## Built-In Recipes (( role: reference ))
 
 Three example recipes ship with GBrain (see `~/.gbrain/recipes/`):
 
@@ -112,14 +115,14 @@
 2. **expense-tracker** — extract amounts, recipients, platforms from receipt emails (subscriptions, services, recurring charges)
 3. **company-updates** — extract revenue, users, key metrics from portfolio company update emails
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Trusting LLM working memory for amounts after batch processing (use extraction integrity rule)
 - Creating tracker entries without raw source links
 - Running without deduplication (leads to double-counted entries)
 - Hardcoding source-specific patterns in the pipeline code (use recipes)
 
-## Output Format
+## Output Format (( role: template ))
 
 Brain page at the recipe's `tracker_page` path with markdown tables:
 
```
