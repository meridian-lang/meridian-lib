# Deviation: data_research.meri

- Original: `data-research/SKILL.md`
- Ported: `data_research.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 139 -> 148 (+15 / -6)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L104 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/14 (7% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 9 blocks, 0 lines

### Inert section details
- L104 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/data-research/SKILL.md
+++ skills/data_research.meri
@@ -28,17 +28,19 @@
 
 # Data Research
 
-Structured research pipeline: search sources, extract structured data,
-archive raw, deduplicate, update canonical trackers, backlink entities.
+> Structured research pipeline: search sources, extract structured data,
+> archive raw, deduplicate, update canonical trackers, backlink entities.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 One skill for any email-to-structured-data pipeline. The only differences
 between tracking investor updates, expenses, and company metrics
 are the **search queries**, **extraction schemas**, and **tracker page format**.
 All three use the same 7-phase pipeline with parameterized recipes.
 
-## When to Use
+## When to Use (( role: procedure ))
+use judgment to follow the When to Use guidance:
 
 - User wants to track structured data from email, web, or API sources
 - User says "research", "track", "extract from email", "build a tracker"
@@ -46,8 +48,10 @@
 - User wants to set up recurring data collection (with cron recipe)
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 ### Phase 1: Define Research Recipe
+use judgment to follow the Phase 1: Define Research Recipe guidance:
 
 Ask the user what they want to track. Either:
 - Pick a built-in recipe: investor-updates, expense-tracker, company-updates
@@ -58,6 +62,7 @@
 to scaffold a new one.
 
 ### Phase 2: Search Sources
+use judgment to follow the Phase 2: Search Sources guidance:
 
 Brain first (maybe we already have this data). Then:
 - **Email** via credential gateway: windowed queries (quarterly, monthly if truncated)
@@ -66,12 +71,14 @@
 - **Attachments**: PDF extraction, HTML stripping
 
 ### Phase 3: Classify
+use judgment to follow the Phase 3: Classify guidance:
 
 Deterministic first (regex patterns from recipe), LLM fallback.
 Log every LLM fallback for future regex improvement (fail-improve loop).
 Skip marketing, newsletters, noise based on recipe's classification rules.
 
 ### Phase 4: Extract Structured Data
+use judgment to follow the Phase 4: Extract Structured Data guidance:
 
 **EXTRACTION INTEGRITY RULE:**
 1. Save raw source immediately (before any extraction)
@@ -90,6 +97,7 @@
 - Every tracker entry must link back to its raw source
 
 ### Phase 6: Deduplicate
+use judgment to follow the Phase 6: Deduplicate guidance:
 
 Before adding to tracker:
 - Exact match (same key fields) → skip
@@ -112,14 +120,15 @@
 2. **expense-tracker** — extract amounts, recipients, platforms from receipt emails (subscriptions, services, recurring charges)
 3. **company-updates** — extract revenue, users, key metrics from portfolio company update emails
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Trusting LLM working memory for amounts after batch processing (use extraction integrity rule)
 - Creating tracker entries without raw source links
 - Running without deduplication (leads to double-counted entries)
 - Hardcoding source-specific patterns in the pipeline code (use recipes)
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Brain page at the recipe's `tracker_page` path with markdown tables:
 
```
