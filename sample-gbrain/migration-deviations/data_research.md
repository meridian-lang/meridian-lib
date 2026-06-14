# Deviation: data_research.meri

- Original: `data-research/SKILL.md`
- Ported: `data_research.meri`
- Tier: 3 (structural rewrite)
- Similarity: 49%
- Lines: 139 -> 140 (+72 / -71)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 3/14 inert (21% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 7 blocks, 34 lines

### Inert section details
- L80 `Built-In Recipes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L96 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L110 `Conventions`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/data-research/SKILL.md
+++ skills/data_research.meri
@@ -28,15 +28,15 @@
 
 # Data Research
 
-Structured research pipeline: search sources, extract structured data,
-archive raw, deduplicate, update canonical trackers, backlink entities.
+> Structured research pipeline: search sources, extract structured data,
+> archive raw, deduplicate, update canonical trackers, backlink entities.
 
-## Contract
+## Contract (( role: procedure ))
 
-One skill for any email-to-structured-data pipeline. The only differences
-between tracking investor updates, expenses, and company metrics
-are the **search queries**, **extraction schemas**, and **tracker page format**.
-All three use the same 7-phase pipeline with parameterized recipes.
+> One skill for any email-to-structured-data pipeline. The only differences
+> between tracking investor updates, expenses, and company metrics
+> are the **search queries**, **extraction schemas**, and **tracker page format**.
+> All three use the same 7-phase pipeline with parameterized recipes.
 
 ## When to Use
 
@@ -47,64 +47,64 @@
 
 ## Phases
 
-### Phase 1: Define Research Recipe
+### Phase 1: Define Research Recipe (( role: procedure ))
 
-Ask the user what they want to track. Either:
-- Pick a built-in recipe: investor-updates, expense-tracker, company-updates
-- Define a custom recipe with: source queries, classification rules, extraction schema,
-  tracker page path, tracker format
-
-Recipes are YAML files at `~/.gbrain/recipes/{name}.yaml`. Use `gbrain research init`
-to scaffold a new one.
-
-### Phase 2: Search Sources
-
-Brain first (maybe we already have this data). Then:
-- **Email** via credential gateway: windowed queries (quarterly, monthly if truncated)
-- **Web** via search: public filings, press releases, regulatory data
-- **APIs**: any structured data source the recipe defines
-- **Attachments**: PDF extraction, HTML stripping
-
-### Phase 3: Classify
-
-Deterministic first (regex patterns from recipe), LLM fallback.
-Log every LLM fallback for future regex improvement (fail-improve loop).
-Skip marketing, newsletters, noise based on recipe's classification rules.
-
-### Phase 4: Extract Structured Data
-
-**EXTRACTION INTEGRITY RULE:**
-1. Save raw source immediately (before any extraction)
-2. Extract fields using deterministic regex first, LLM fallback
-3. When summarizing batch results: **re-read from saved files**
-4. Never trust LLM working memory after batch processing
-
-This prevents a known hallucination bug where batch-processed amounts were
-13/13 wrong from LLM working memory while saved files were correct.
-
-### Phase 5: Archive Raw Sources
-
-- `put_raw_data` for email bodies, API responses
-- `file_upload` for PDF attachments, documents
-- Create `.redirect.yaml` pointers for large files in storage
-- Every tracker entry must link back to its raw source
-
-### Phase 6: Deduplicate
-
-Before adding to tracker:
-- Exact match (same key fields) → skip
-- Fuzzy match (same entity + date + similar amount within tolerance) → flag for review
-- Different amount for same entity+date → add with note (could be correction)
-
-### Phase 7: Update Canonical Tracker + Backlink
-
-- Parse existing tracker page (markdown table)
-- Append new entries in correct section (grouped by year/quarter/entity)
-- Compute running totals
-- Backlink every mentioned entity (person → people/ page, company → companies/ page)
-- Uses enrichment service for entity pages
-
-## Built-In Recipes
+use judgment to follow the Phase 1: Define Research Recipe guidance:
+  Ask the user what they want to track. Either:
+  item: Pick a built-in recipe: investor-updates, expense-tracker, company-updates
+  item: Define a custom recipe with: source queries, classification rules, extraction schema,
+    tracker page path, tracker format
+  
+  Recipes are YAML files at `~/.gbrain/recipes/{name}.yaml`. Use `gbrain research init`
+  to scaffold a new one.
+### Phase 2: Search Sources (( role: procedure ))
+  
+use judgment to follow the Phase 2: Search Sources guidance:
+  Brain first (maybe we already have this data). Then:
+  item: **Email** via credential gateway: windowed queries (quarterly, monthly if truncated)
+  item: **Web** via search: public filings, press releases, regulatory data
+  item: **APIs**: any structured data source the recipe defines
+  item: **Attachments**: PDF extraction, HTML stripping
+### Phase 3: Classify (( role: procedure ))
+  
+use judgment to follow the Phase 3: Classify guidance:
+  Deterministic first (regex patterns from recipe), LLM fallback.
+  Log every LLM fallback for future regex improvement (fail-improve loop).
+  Skip marketing, newsletters, noise based on recipe's classification rules.
+### Phase 4: Extract Structured Data (( role: procedure ))
+  
+use judgment to follow the Phase 4: Extract Structured Data guidance:
+  **EXTRACTION INTEGRITY RULE:**
+  1. Save raw source immediately (before any extraction)
+  2. Extract fields using deterministic regex first, LLM fallback
+  3. When summarizing batch results: **re-read from saved files**
+  4. Never trust LLM working memory after batch processing
+  
+  This prevents a known hallucination bug where batch-processed amounts were
+  13/13 wrong from LLM working memory while saved files were correct.
+### Phase 5: Archive Raw Sources (( role: procedure ))
+  
+use judgment to follow the Phase 5: Archive Raw Sources guidance:
+  item: `put_raw_data` for email bodies, API responses
+  item: `file_upload` for PDF attachments, documents
+  item: Create `.redirect.yaml` pointers for large files in storage
+  item: Every tracker entry must link back to its raw source
+### Phase 6: Deduplicate (( role: procedure ))
+  
+use judgment to follow the Phase 6: Deduplicate guidance:
+  Before adding to tracker:
+  item: Exact match (same key fields) → skip
+  item: Fuzzy match (same entity + date + similar amount within tolerance) → flag for review
+  item: Different amount for same entity+date → add with note (could be correction)
+### Phase 7: Update Canonical Tracker + Backlink (( role: procedure ))
+  
+use judgment to follow the Phase 7: Update Canonical Tracker + Backlink guidance:
+  item: Parse existing tracker page (markdown table)
+  item: Append new entries in correct section (grouped by year/quarter/entity)
+  item: Compute running totals
+  item: Backlink every mentioned entity (person → people/ page, company → companies/ page)
+  item: Uses enrichment service for entity pages
+## Built-In Recipes (( inert ))
 
 Three example recipes ship with GBrain (see `~/.gbrain/recipes/`):
 
@@ -112,19 +112,20 @@
 2. **expense-tracker** — extract amounts, recipients, platforms from receipt emails (subscriptions, services, recurring charges)
 3. **company-updates** — extract revenue, users, key metrics from portfolio company update emails
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Trusting LLM working memory for amounts after batch processing (use extraction integrity rule)
-- Creating tracker entries without raw source links
-- Running without deduplication (leads to double-counted entries)
-- Hardcoding source-specific patterns in the pipeline code (use recipes)
+!!! checklist (( ai-autonomy ))
+- [ ] Trusting LLM working memory for amounts after batch processing (use extraction integrity rule)
+- [ ] Creating tracker entries without raw source links
+- [ ] Running without deduplication (leads to double-counted entries)
+- [ ] Hardcoding source-specific patterns in the pipeline code (use recipes)
 
 ## Output Format
 
 Brain page at the recipe's `tracker_page` path with markdown tables:
 
 ```markdown
-### 2026
+### 2026 (( inert ))
 
 | Date | Company | MRR | ARR | Growth | Status |
 |------|---------|-----|-----|--------|--------|
@@ -133,7 +134,7 @@
 
 Each entry links to its raw source. Running totals at the bottom of each section.
 
-## Conventions
+## Conventions (( inert ))
 
 References `skills/conventions/quality.md` for citation and back-linking rules.
 
```
