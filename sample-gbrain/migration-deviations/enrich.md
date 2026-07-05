# Deviation: enrich.meri

- Original: `enrich/SKILL.md`
- Ported: `enrich.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 350 -> 368 (+45 / -27)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L26 `Philosophy`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `Citation Requirements (MANDATORY)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L40 `Primary triggers`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Do NOT enrich`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Step 1: Identify entities`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L72 `Step 2: Check brain state`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L136 `Step 5: Save raw data (preserves provenance)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L170 `Person page template`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L232 `Company page template`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L275 `Bulk Enrichment Rules`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L284 `Validation Rules`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L292 `Report Storage`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L303 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L310 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L331 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 19/21 (90% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=17, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L26 `Philosophy`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L32 `Citation Requirements (MANDATORY)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L40 `Primary triggers`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Do NOT enrich`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Enrichment Tiers`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Step 1: Identify entities`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L72 `Step 2: Check brain state`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L96 `Step 4: External data source lookups`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L136 `Step 5: Save raw data (preserves provenance)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L170 `Person page template`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L232 `Company page template`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L259 `Step 7: Cross-reference`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L275 `Bulk Enrichment Rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L284 `Validation Rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L292 `Report Storage`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L303 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L310 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L331 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/enrich/SKILL.md
+++ skills/enrich.meri
@@ -28,9 +28,9 @@
 
 # Enrich Skill
 
-Enrich person and company pages from external sources. Scale effort to importance.
-
-## Contract
+> Enrich person and company pages from external sources. Scale effort to importance.
+
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Every enriched page has compiled truth (State section) with inline citations
@@ -43,40 +43,46 @@
 
 > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
+
+### Contract — steps (( role: reference ))
+
 Every mention of a person or company with a brain page MUST create a back-link
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
 broken brain. See `skills/_brain-filing-rules.md` for format.
 
-## Philosophy
+## Philosophy (( role: reference ))
 
 A brain page should read like an intelligence dossier, not a LinkedIn scrape.
 Facts are table stakes. Texture is the value -- what do they believe, what are
 they building, what makes them tick, where are they headed.
 
-## Citation Requirements (MANDATORY)
+## Citation Requirements (MANDATORY) (( role: reference ))
 
 > **Convention:** see `skills/conventions/quality.md` for citation formats and source precedence.
 
 When sources conflict, note the contradiction with both citations.
 
-## When To Enrich
-
-### Primary triggers
+## When To Enrich (( role: reference ))
+
+### Primary triggers (( role: reference ))
 - User mentions an entity in conversation
 - Entity appears in a meeting transcript or email
 - New contact appears with significant context
 - Entity makes news or has a major event
 - Any ingest pipeline encounters a notable entity
 
-### Do NOT enrich
+### Do NOT enrich (( role: reference ))
 - Random mentions with no relationship signal
 - Bot/spam accounts
 - Entities with no substantive connection to the user's work
 - Same page enriched within the past week (unless new signal warrants it)
 
-## Enrichment Tiers
+## Enrichment Tiers (( role: reference ))
 
 Scale enrichment to importance. Don't waste API calls on low-value entities.
+
+
+### Enrichment Tiers — steps (( role: reference ))
 
 | Tier | Who | Effort | Sources |
 |------|-----|--------|---------|
@@ -84,13 +90,13 @@
 | 2 (notable) | Occasional interactions, industry figures | Moderate | Web research + social + brain cross-ref |
 | 3 (minor) | Worth tracking, not critical | Light | Brain cross-ref + social lookup if handle known |
 
-## The Enrichment Protocol (7 Steps)
-
-### Step 1: Identify entities
+## The Enrichment Protocol (7 Steps) (( role: reference ))
+
+### Step 1: Identify entities (( role: reference ))
 
 Extract people, companies, concepts from the incoming signal.
 
-### Step 2: Check brain state
+### Step 2: Check brain state (( role: reference ))
 
 For each entity:
 - `gbrain search "name"` -- does a page already exist?
@@ -99,7 +105,10 @@
 
 ### Step 3: Extract signal from source
 
-Don't just capture facts. Capture texture:
+
+### Step 3: Extract signal from source — steps (( role: reference ))
+
+> Don't just capture facts. Capture texture:
 
 | Signal Type | What to Extract |
 |-------------|----------------|
@@ -111,11 +120,10 @@
 | Ascending, plateauing, pivoting? | Trajectory section |
 | Role, company, funding, location | State section (hard facts) |
 
-### Step 4: External data source lookups
+### Step 4: External data source lookups (( role: reference ))
 
 Priority order -- stop when you have enough signal for the entity's tier.
 
-**4a. Brain cross-reference (always, all tiers)**
 - `gbrain search "name"` and `gbrain query "what do we know about name"`
 - Check related pages: company pages for person enrichment and vice versa
 - This is free and often the richest source
@@ -135,6 +143,13 @@
 
 **4e. Company enrichment APIs (Tier 1)**
 - Company data, financials, headcount, key hires, recent news
+
+
+### Step 4: External data source lookups — steps (( role: reference ))
+
+4a. Brain cross-reference (always, all tiers)
+
+### Step 4: External data source lookups — steps 2 (( role: reference ))
 
 | Data Need | Example Sources | Tier |
 |-----------|----------------|------|
@@ -145,7 +160,7 @@
 | Social media | Platform APIs, web scraping | 1-3 |
 | Meeting history | Calendar/meeting transcript tools | 1-2 |
 
-### Step 5: Save raw data (preserves provenance)
+### Step 5: Save raw data (preserves provenance) (( role: reference ))
 
 Store raw API responses via `put_raw_data` in gbrain:
 ```json
@@ -160,7 +175,7 @@
 Raw data preserves provenance. If the compiled truth is ever questioned,
 the raw data shows exactly what the API returned.
 
-### Step 6: Write to brain
+### Step 6: Write to brain (( role: reference ))
 
 #### CREATE path
 
@@ -179,7 +194,7 @@
 4. Flag contradictions between new signal and existing compiled truth
 5. Don't overwrite user-written assessments with API boilerplate
 
-#### Person page template
+#### Person page template (( role: reference ))
 
 ```markdown
 ---
@@ -241,7 +256,7 @@
 - **YYYY-MM-DD** | Event description [Source: ...]
 ```
 
-#### Company page template
+#### Company page template (( role: reference ))
 
 ```markdown
 ---
@@ -268,7 +283,7 @@
 - **YYYY-MM-DD** | Event description [Source: ...]
 ```
 
-### Step 7: Cross-reference
+### Step 7: Cross-reference (( role: reference ))
 
 - Update company pages from person enrichment (and vice versa)
 - Update related project/deal pages if relevant context surfaced
@@ -279,9 +294,12 @@
 cross-references (updating related pages' compiled truth with new signal
 from this enrichment), not on creating links. Verify via the `auto_links`
 field in the put_page response (`{ created, removed, errors }`).
+
+### Step 7: Cross-reference — steps
+
 Timeline entries still need explicit `gbrain timeline-add` calls.
 
-## Bulk Enrichment Rules
+## Bulk Enrichment Rules (( role: reference ))
 
 - **Test on 3-5 entities first.** Read actual output. Check quality.
 - Only proceed to bulk after test shots pass your quality bar.
@@ -290,7 +308,7 @@
 - Commit every 5-10 entities during bulk runs.
 - Save a report after bulk enrichment (see Report Storage below).
 
-## Validation Rules
+## Validation Rules (( role: reference ))
 
 - Connection count < 20 on LinkedIn = likely wrong person, skip
 - Name mismatch between brain and API = skip, flag for review
@@ -298,7 +316,7 @@
 - Don't overwrite user-written assessments with API boilerplate
 - When in doubt: save raw data but don't update brain page
 
-## Report Storage
+## Report Storage (( role: reference ))
 
 After enrichment sweeps, save a report:
 - Number of entities processed
@@ -309,14 +327,14 @@
 
 This creates an audit trail for brain enrichment over time.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Creating stub pages with no content
 - Enriching without checking brain first
 - Overwriting user's direct statements with API data
 - Creating pages for non-notable entities
 
-## Output Format
+## Output Format (( role: template ))
 
 An enriched person page contains:
 - **Frontmatter** with type, tags, company, relationship, and contact fields
```
