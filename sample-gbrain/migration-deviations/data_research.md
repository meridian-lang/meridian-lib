# Deviation: data_research.meri

- Original: `data-research/SKILL.md`
- Ported: `data_research.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 139 -> 139 (+17 / -17)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L7 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L14 `When to Use`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L21 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L23 `Phase 1: Define Research Recipe`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L33 `Phase 2: Search Sources`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L41 `Phase 3: Classify`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L47 `Phase 4: Extract Structured Data`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L58 `Phase 5: Archive Raw Sources`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L65 `Phase 6: Deduplicate`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L72 `Phase 7: Update Canonical Tracker + Backlink`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L80 `Built-In Recipes`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L88 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L95 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L109 `Conventions`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 14/14 inert (100% inert ratio)
- Operational inert: 10
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=9, reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L7 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L14 `When to Use`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L21 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L23 `Phase 1: Define Research Recipe`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L33 `Phase 2: Search Sources`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L41 `Phase 3: Classify`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L47 `Phase 4: Extract Structured Data`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L58 `Phase 5: Archive Raw Sources`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L65 `Phase 6: Deduplicate`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L72 `Phase 7: Update Canonical Tracker + Backlink`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L80 `Built-In Recipes`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L88 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L95 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L109 `Conventions`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/data-research/SKILL.md
+++ skills/data_research.meri
@@ -28,26 +28,26 @@
 
 # Data Research
 
-Structured research pipeline: search sources, extract structured data,
-archive raw, deduplicate, update canonical trackers, backlink entities.
+> Structured research pipeline: search sources, extract structured data,
+> archive raw, deduplicate, update canonical trackers, backlink entities.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 One skill for any email-to-structured-data pipeline. The only differences
 between tracking investor updates, expenses, and company metrics
 are the **search queries**, **extraction schemas**, and **tracker page format**.
 All three use the same 7-phase pipeline with parameterized recipes.
 
-## When to Use
+## When to Use (( inert, role: applicability ))
 
 - User wants to track structured data from email, web, or API sources
 - User says "research", "track", "extract from email", "build a tracker"
 - User mentions investor updates, donations, company metrics, filings
 - User wants to set up recurring data collection (with cron recipe)
 
-## Phases
+## Phases (( inert, role: procedure ))
 
-### Phase 1: Define Research Recipe
+### Phase 1: Define Research Recipe (( inert, role: procedure ))
 
 Ask the user what they want to track. Either:
 - Pick a built-in recipe: investor-updates, expense-tracker, company-updates
@@ -57,7 +57,7 @@
 Recipes are YAML files at `~/.gbrain/recipes/{name}.yaml`. Use `gbrain research init`
 to scaffold a new one.
 
-### Phase 2: Search Sources
+### Phase 2: Search Sources (( inert, role: procedure ))
 
 Brain first (maybe we already have this data). Then:
 - **Email** via credential gateway: windowed queries (quarterly, monthly if truncated)
@@ -65,13 +65,13 @@
 - **APIs**: any structured data source the recipe defines
 - **Attachments**: PDF extraction, HTML stripping
 
-### Phase 3: Classify
+### Phase 3: Classify (( inert, role: procedure ))
 
 Deterministic first (regex patterns from recipe), LLM fallback.
 Log every LLM fallback for future regex improvement (fail-improve loop).
 Skip marketing, newsletters, noise based on recipe's classification rules.
 
-### Phase 4: Extract Structured Data
+### Phase 4: Extract Structured Data (( inert, role: procedure ))
 
 **EXTRACTION INTEGRITY RULE:**
 1. Save raw source immediately (before any extraction)
@@ -82,21 +82,21 @@
 This prevents a known hallucination bug where batch-processed amounts were
 13/13 wrong from LLM working memory while saved files were correct.
 
-### Phase 5: Archive Raw Sources
+### Phase 5: Archive Raw Sources (( inert, role: procedure ))
 
 - `put_raw_data` for email bodies, API responses
 - `file_upload` for PDF attachments, documents
 - Create `.redirect.yaml` pointers for large files in storage
 - Every tracker entry must link back to its raw source
 
-### Phase 6: Deduplicate
+### Phase 6: Deduplicate (( inert, role: procedure ))
 
 Before adding to tracker:
 - Exact match (same key fields) → skip
 - Fuzzy match (same entity + date + similar amount within tolerance) → flag for review
 - Different amount for same entity+date → add with note (could be correction)
 
-### Phase 7: Update Canonical Tracker + Backlink
+### Phase 7: Update Canonical Tracker + Backlink (( inert, role: procedure ))
 
 - Parse existing tracker page (markdown table)
 - Append new entries in correct section (grouped by year/quarter/entity)
@@ -104,7 +104,7 @@
 - Backlink every mentioned entity (person → people/ page, company → companies/ page)
 - Uses enrichment service for entity pages
 
-## Built-In Recipes
+## Built-In Recipes (( inert ))
 
 Three example recipes ship with GBrain (see `~/.gbrain/recipes/`):
 
@@ -112,19 +112,19 @@
 2. **expense-tracker** — extract amounts, recipients, platforms from receipt emails (subscriptions, services, recurring charges)
 3. **company-updates** — extract revenue, users, key metrics from portfolio company update emails
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Trusting LLM working memory for amounts after batch processing (use extraction integrity rule)
 - Creating tracker entries without raw source links
 - Running without deduplication (leads to double-counted entries)
 - Hardcoding source-specific patterns in the pipeline code (use recipes)
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Brain page at the recipe's `tracker_page` path with markdown tables:
 
 ```markdown
-### 2026
+### 2026 (( inert ))
 
 | Date | Company | MRR | ARR | Growth | Status |
 |------|---------|-----|-----|--------|--------|
@@ -133,7 +133,7 @@
 
 Each entry links to its raw source. Running totals at the bottom of each section.
 
-## Conventions
+## Conventions (( inert ))
 
 References `skills/conventions/quality.md` for citation and back-linking rules.
 
```
