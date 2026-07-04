# Deviation: enrich.meri

- Original: `enrich/SKILL.md`
- Ported: `enrich.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 350 -> 364 (+36 / -22)

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
- L24 `Philosophy`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L69 `Step 1: Identify entities`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L133 `Step 5: Save raw data (preserves provenance)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L167 `Person page template`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L229 `Company page template`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L287 `Report Storage`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L306 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L327 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 9/21 (43% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=7, template=1, tools-metadata=1
- Judgment: 6 blocks, 0 lines

### Inert section details
- L24 `Philosophy`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L53 `Enrichment Tiers`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L69 `Step 1: Identify entities`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L133 `Step 5: Save raw data (preserves provenance)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L167 `Person page template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L229 `Company page template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L287 `Report Storage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L306 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L327 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/enrich/SKILL.md
+++ skills/enrich.meri
@@ -28,9 +28,10 @@
 
 # Enrich Skill
 
-Enrich person and company pages from external sources. Scale effort to importance.
-
-## Contract
+> Enrich person and company pages from external sources. Scale effort to importance.
+
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Every enriched page has compiled truth (State section) with inline citations
@@ -47,21 +48,23 @@
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
 broken brain. See `skills/_brain-filing-rules.md` for format.
 
-## Philosophy
+## Philosophy (( inert ))
 
 A brain page should read like an intelligence dossier, not a LinkedIn scrape.
 Facts are table stakes. Texture is the value -- what do they believe, what are
 they building, what makes them tick, where are they headed.
 
 ## Citation Requirements (MANDATORY)
+use judgment to follow the Citation Requirements (MANDATORY) guidance:
 
 > **Convention:** see `skills/conventions/quality.md` for citation formats and source precedence.
 
 When sources conflict, note the contradiction with both citations.
 
-## When To Enrich
-
-### Primary triggers
+## When To Enrich (( inert ))
+
+### Primary triggers (( role: procedure ))
+use judgment to follow the Primary triggers guidance:
 - User mentions an entity in conversation
 - Entity appears in a meeting transcript or email
 - New contact appears with significant context
@@ -74,19 +77,23 @@
 - Entities with no substantive connection to the user's work
 - Same page enriched within the past week (unless new signal warrants it)
 
-## Enrichment Tiers
+## Enrichment Tiers (( inert ))
 
 Scale enrichment to importance. Don't waste API calls on low-value entities.
 
+
+### Enrichment Tiers — steps
+
+!!! table (( ai-discretion ))
 | Tier | Who | Effort | Sources |
 |------|-----|--------|---------|
 | 1 (key) | Inner circle, close collaborators, key contacts | Full pipeline | All available APIs + deep web research |
 | 2 (notable) | Occasional interactions, industry figures | Moderate | Web research + social + brain cross-ref |
 | 3 (minor) | Worth tracking, not critical | Light | Brain cross-ref + social lookup if handle known |
 
-## The Enrichment Protocol (7 Steps)
-
-### Step 1: Identify entities
+## The Enrichment Protocol (7 Steps) (( inert ))
+
+### Step 1: Identify entities (( inert ))
 
 Extract people, companies, concepts from the incoming signal.
 
@@ -97,10 +104,14 @@
 - **If yes:** UPDATE path (add new signal, update compiled truth if material)
 - **If no:** CREATE path (check notability gate first, then create)
 
-### Step 3: Extract signal from source
-
-Don't just capture facts. Capture texture:
-
+### Step 3: Extract signal from source (( inert ))
+
+
+#### Step 3: Extract signal from source — steps
+
+> Don't just capture facts. Capture texture:
+
+!!! table (( ai-discretion ))
 | Signal Type | What to Extract |
 |-------------|----------------|
 | Opinions, beliefs | What They Believe section |
@@ -112,6 +123,7 @@
 | Role, company, funding, location | State section (hard facts) |
 
 ### Step 4: External data source lookups
+use judgment to follow the Step 4: External data source lookups guidance:
 
 Priority order -- stop when you have enough signal for the entity's tier.
 
@@ -145,7 +157,7 @@
 | Social media | Platform APIs, web scraping | 1-3 |
 | Meeting history | Calendar/meeting transcript tools | 1-2 |
 
-### Step 5: Save raw data (preserves provenance)
+### Step 5: Save raw data (preserves provenance) (( inert ))
 
 Store raw API responses via `put_raw_data` in gbrain:
 ```json
@@ -160,7 +172,7 @@
 Raw data preserves provenance. If the compiled truth is ever questioned,
 the raw data shows exactly what the API returned.
 
-### Step 6: Write to brain
+### Step 6: Write to brain (( inert ))
 
 #### CREATE path
 
@@ -179,7 +191,7 @@
 4. Flag contradictions between new signal and existing compiled truth
 5. Don't overwrite user-written assessments with API boilerplate
 
-#### Person page template
+#### Person page template (( inert ))
 
 ```markdown
 ---
@@ -241,7 +253,7 @@
 - **YYYY-MM-DD** | Event description [Source: ...]
 ```
 
-#### Company page template
+#### Company page template (( inert ))
 
 ```markdown
 ---
@@ -269,6 +281,7 @@
 ```
 
 ### Step 7: Cross-reference
+use judgment to follow the Step 7: Cross-reference guidance:
 
 - Update company pages from person enrichment (and vice versa)
 - Update related project/deal pages if relevant context surfaced
@@ -298,7 +311,7 @@
 - Don't overwrite user-written assessments with API boilerplate
 - When in doubt: save raw data but don't update brain page
 
-## Report Storage
+## Report Storage (( inert ))
 
 After enrichment sweeps, save a report:
 - Number of entities processed
@@ -309,14 +322,15 @@
 
 This creates an audit trail for brain enrichment over time.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Creating stub pages with no content
 - Enriching without checking brain first
 - Overwriting user's direct statements with API data
 - Creating pages for non-notable entities
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 An enriched person page contains:
 - **Frontmatter** with type, tags, company, relationship, and contact fields
```
