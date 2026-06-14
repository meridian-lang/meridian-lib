# Deviation: enrich.meri

- Original: `enrich/SKILL.md`
- Ported: `enrich.meri`
- Tier: 2 (light edits)
- Similarity: 63%
- Lines: 350 -> 348 (+128 / -130)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 19/25 inert (76% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=17, template=1, tools-metadata=1
- Judgment: 3 blocks, 41 lines

### Inert section details
- L20 `Philosophy`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L26 `Citation Requirements (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L32 `When To Enrich`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L41 `Do NOT enrich`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L57 `The Enrichment Protocol (7 Steps)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L59 `Step 1: Identify entities`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L63 `Step 2: Check brain state`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L118 `Step 5: Save raw data (preserves provenance)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L133 `Step 6: Write to brain`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L135 `CREATE path`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L144 `UPDATE path`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L152 `Person page template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L214 `Company page template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L241 `Step 7: Cross-reference`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L254 `Bulk Enrichment Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L263 `Validation Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L271 `Report Storage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L290 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L311 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/enrich/SKILL.md
+++ skills/enrich.meri
@@ -28,125 +28,122 @@
 
 # Enrich Skill
 
-Enrich person and company pages from external sources. Scale effort to importance.
-
-## Contract
-
-This skill guarantees:
-- Every enriched page has compiled truth (State section) with inline citations
-- Every enriched page has a timeline with dated entries
-- Back-links are created bidirectionally
-- Tiered enrichment: Tier 1 (full), Tier 2 (medium), Tier 3 (minimal) based on notability
-- No stubs: every new page has meaningful content from web search or existing brain context
-
-> **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
-
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
-
-Every mention of a person or company with a brain page MUST create a back-link
-FROM that entity's page TO the page mentioning them. An unlinked mention is a
-broken brain. See `skills/_brain-filing-rules.md` for format.
-
-## Philosophy
+> Enrich person and company pages from external sources. Scale effort to importance.
+
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Every enriched page has compiled truth (State section) with inline citations
+- [ ] Every enriched page has a timeline with dated entries
+- [ ] Back-links are created bidirectionally
+- [ ] Tiered enrichment: Tier 1 (full), Tier 2 (medium), Tier 3 (minimal) based on notability
+- [ ] No stubs: every new page has meaningful content from web search or existing brain context
+
+> > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
+
+> > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+
+## Philosophy (( inert ))
 
 A brain page should read like an intelligence dossier, not a LinkedIn scrape.
 Facts are table stakes. Texture is the value -- what do they believe, what are
 they building, what makes them tick, where are they headed.
 
-## Citation Requirements (MANDATORY)
+## Citation Requirements (MANDATORY) (( inert ))
 
 > **Convention:** see `skills/conventions/quality.md` for citation formats and source precedence.
 
 When sources conflict, note the contradiction with both citations.
 
-## When To Enrich
+## When To Enrich (( inert ))
 
 ### Primary triggers
 - User mentions an entity in conversation
 - Entity appears in a meeting transcript or email
 - New contact appears with significant context
-- Entity makes news or has a major event
+- the entity appears in major news
 - Any ingest pipeline encounters a notable entity
 
-### Do NOT enrich
+### Do NOT enrich (( inert ))
 - Random mentions with no relationship signal
 - Bot/spam accounts
 - Entities with no substantive connection to the user's work
-- Same page enriched within the past week (unless new signal warrants it)
-
-## Enrichment Tiers
-
-Scale enrichment to importance. Don't waste API calls on low-value entities.
-
-| Tier | Who | Effort | Sources |
-|------|-----|--------|---------|
-| 1 (key) | Inner circle, close collaborators, key contacts | Full pipeline | All available APIs + deep web research |
-| 2 (notable) | Occasional interactions, industry figures | Moderate | Web research + social + brain cross-ref |
-| 3 (minor) | Worth tracking, not critical | Light | Brain cross-ref + social lookup if handle known |
-
-## The Enrichment Protocol (7 Steps)
-
-### Step 1: Identify entities
+- a page already enriched recently
+
+## Enrichment Tiers (( role: procedure ))
+
+use judgment to follow the Enrichment Tiers guidance:
+  Scale enrichment to importance. Don't waste API calls on low-value entities.
+  
+  | Tier | Who | Effort | Sources |
+  |------|-----|--------|---------|
+  | 1 (key) | Inner circle, close collaborators, key contacts | Full pipeline | All available APIs + deep web research |
+  | 2 (notable) | Occasional interactions, industry figures | Moderate | Web research + social + brain cross-ref |
+  | 3 (minor) | Worth tracking, not critical | Light | Brain cross-ref + social lookup if handle known |
+## The Enrichment Protocol (7 Steps) (( inert ))
+
+### Step 1: Identify entities (( inert ))
 
 Extract people, companies, concepts from the incoming signal.
 
-### Step 2: Check brain state
+### Step 2: Check brain state (( inert ))
 
 For each entity:
 - `gbrain search "name"` -- does a page already exist?
 - **If yes:** UPDATE path (add new signal, update compiled truth if material)
 - **If no:** CREATE path (check notability gate first, then create)
 
-### Step 3: Extract signal from source
-
-Don't just capture facts. Capture texture:
-
-| Signal Type | What to Extract |
-|-------------|----------------|
-| Opinions, beliefs | What They Believe section |
-| Current projects, features shipped | What They're Building section |
-| Ambition, career arc, motivation | What Motivates Them section |
-| Topics they return to obsessively | Hobby Horses section |
-| Who they amplify, argue with, respect | Network / Relationships |
-| Ascending, plateauing, pivoting? | Trajectory section |
-| Role, company, funding, location | State section (hard facts) |
-
-### Step 4: External data source lookups
-
-Priority order -- stop when you have enough signal for the entity's tier.
-
-**4a. Brain cross-reference (always, all tiers)**
-- `gbrain search "name"` and `gbrain query "what do we know about name"`
-- Check related pages: company pages for person enrichment and vice versa
-- This is free and often the richest source
-
-**4b. Web research (Tier 1 and 2)**
-- Use Perplexity, Brave Search, Exa, or equivalent web research tool
-- **Key pattern:** Send existing brain knowledge as context so the search
-  returns DELTA (what's new vs what you already know), not a rehash
-- Opus-class models for Tier 1 deep research, lighter models for Tier 2
-
-**4c. Social media lookup (all tiers when handle known)**
-- Pull recent posts/tweets for tone, interests, current focus
-- Social media is the highest-texture signal for what someone actually thinks
-
-**4d. People enrichment APIs (Tier 1)**
-- LinkedIn data, career history, connections, education
-
-**4e. Company enrichment APIs (Tier 1)**
-- Company data, financials, headcount, key hires, recent news
-
-| Data Need | Example Sources | Tier |
-|-----------|----------------|------|
-| Web research | Perplexity, Brave, Exa | 1-2 |
-| LinkedIn / career | Crustdata, Proxycurl, People Data Labs | 1 |
-| Career history | Happenstance, LinkedIn | 1 |
-| Funding / company data | Crunchbase, PitchBook, Clearbit | 1 |
-| Social media | Platform APIs, web scraping | 1-3 |
-| Meeting history | Calendar/meeting transcript tools | 1-2 |
-
-### Step 5: Save raw data (preserves provenance)
-
+### Step 3: Extract signal from source (( role: procedure ))
+
+use judgment to follow the Step 3: Extract signal from source guidance:
+  Don't just capture facts. Capture texture:
+  
+  | Signal Type | What to Extract |
+  |-------------|----------------|
+  | Opinions, beliefs | What They Believe section |
+  | Current projects, features shipped | What They're Building section |
+  | Ambition, career arc, motivation | What Motivates Them section |
+  | Topics they return to obsessively | Hobby Horses section |
+  | Who they amplify, argue with, respect | Network / Relationships |
+  | Ascending, plateauing, pivoting? | Trajectory section |
+  | Role, company, funding, location | State section (hard facts) |
+### Step 4: External data source lookups (( role: procedure ))
+  
+use judgment to follow the Step 4: External data source lookups guidance:
+  Priority order -- stop when you have enough signal for the entity's tier.
+  
+  **4a. Brain cross-reference (always, all tiers)**
+  item: `gbrain search "name"` and `gbrain query "what do we know about name"`
+  item: Check related pages: company pages for person enrichment and vice versa
+  item: This is free and often the richest source
+  
+  **4b. Web research (Tier 1 and 2)**
+  item: Use Perplexity, Brave Search, Exa, or equivalent web research tool
+  item: **Key pattern:** Send existing brain knowledge as context so the search
+    returns DELTA (what's new vs what you already know), not a rehash
+  item: Opus-class models for Tier 1 deep research, lighter models for Tier 2
+  
+  **4c. Social media lookup (all tiers when handle known)**
+  item: Pull recent posts/tweets for tone, interests, current focus
+  item: Social media is the highest-texture signal for what someone actually thinks
+  
+  **4d. People enrichment APIs (Tier 1)**
+  item: LinkedIn data, career history, connections, education
+  
+  **4e. Company enrichment APIs (Tier 1)**
+  item: Company data, financials, headcount, key hires, recent news
+  
+  | Data Need | Example Sources | Tier |
+  |-----------|----------------|------|
+  | Web research | Perplexity, Brave, Exa | 1-2 |
+  | LinkedIn / career | Crustdata, Proxycurl, People Data Labs | 1 |
+  | Career history | Happenstance, LinkedIn | 1 |
+  | Funding / company data | Crunchbase, PitchBook, Clearbit | 1 |
+  | Social media | Platform APIs, web scraping | 1-3 |
+  | Meeting history | Calendar/meeting transcript tools | 1-2 |
+### Step 5: Save raw data (preserves provenance) (( inert ))
+  
 Store raw API responses via `put_raw_data` in gbrain:
 ```json
 {
@@ -156,31 +153,31 @@
   "data": { ... }
 }
 ```
-
+  
 Raw data preserves provenance. If the compiled truth is ever questioned,
 the raw data shows exactly what the API returned.
-
-### Step 6: Write to brain
-
-#### CREATE path
-
+  
+### Step 6: Write to brain (( inert ))
+  
+#### CREATE path (( inert ))
+  
 1. Check notability gate (see `skills/_brain-filing-rules.md`)
 2. Check filing rules -- where does this entity go?
 3. Create page with the appropriate template (below)
 4. Fill compiled truth with citations
 5. Add first timeline entry
 6. Leave empty sections as `[No data yet]` (don't fill with boilerplate)
-
-#### UPDATE path
-
+  
+#### UPDATE path (( inert ))
+  
 1. Add new timeline entries (reverse-chronological, append-only)
 2. Update compiled truth ONLY if the new signal materially changes the picture
 3. Update State section with new facts
 4. Flag contradictions between new signal and existing compiled truth
 5. Don't overwrite user-written assessments with API boilerplate
-
-#### Person page template
-
+  
+#### Person page template (( inert ))
+  
 ```markdown
 ---
 title: Full Name
@@ -195,53 +192,53 @@
 twitter:
 location:
 ---
-
+  
 # Full Name
-
+  
 > 1-paragraph executive summary: HOW do you know them, WHY do they matter,
 > what's the current state of the relationship.
 
-## State
+## State (( inert ))
 Role, company, key context. Hard facts only.
 
-## What They Believe
+## What They Believe (( inert ))
 Ideology, first principles, worldview. What hills do they die on?
 
-## What They're Building
+## What They're Building (( inert ))
 Current projects, recent launches, what they're focused on.
 
-## What Motivates Them
+## What Motivates Them (( inert ))
 Ambition, career arc, what drives them.
 
-## Hobby Horses
+## Hobby Horses (( inert ))
 Topics they return to obsessively. Recurring themes in their work/posts.
 
-## Assessment
+## Assessment (( inert ))
 Your read on this person. Strengths, gaps, trajectory.
 
-## Trajectory
+## Trajectory (( inert ))
 Ascending, plateauing, pivoting, declining? Where are they headed?
 
-## Relationship
+## Relationship (( inert ))
 History of interactions, shared context, relationship quality.
 
-## Contact
+## Contact (( inert ))
 Email, social handles, preferred communication channel.
 
-## Network
+## Network (( inert ))
 Key connections, mutual contacts, organizational relationships.
 
-## Open Threads
+## Open Threads (( inert ))
 Active conversations, pending items, things to follow up on.
 
 ---
 
-## Timeline
+## Timeline (( inert ))
 Reverse chronological. Every entry has a date and [Source: ...] citation.
 - **YYYY-MM-DD** | Event description [Source: ...]
 ```
 
-#### Company page template
+#### Company page template (( inert ))
 
 ```markdown
 ---
@@ -256,19 +253,19 @@
 
 > 1-paragraph executive summary.
 
-## State
+## State (( inert ))
 What they do, stage, key people, key metrics, your connection.
 
-## Open Threads
+## Open Threads (( inert ))
 Active items, pending decisions, things to track.
 
 ---
 
-## Timeline
+## Timeline (( inert ))
 - **YYYY-MM-DD** | Event description [Source: ...]
 ```
 
-### Step 7: Cross-reference
+### Step 7: Cross-reference (( inert ))
 
 - Update company pages from person enrichment (and vice versa)
 - Update related project/deal pages if relevant context surfaced
@@ -281,7 +278,7 @@
 field in the put_page response (`{ created, removed, errors }`).
 Timeline entries still need explicit `gbrain timeline-add` calls.
 
-## Bulk Enrichment Rules
+## Bulk Enrichment Rules (( inert ))
 
 - **Test on 3-5 entities first.** Read actual output. Check quality.
 - Only proceed to bulk after test shots pass your quality bar.
@@ -290,7 +287,7 @@
 - Commit every 5-10 entities during bulk runs.
 - Save a report after bulk enrichment (see Report Storage below).
 
-## Validation Rules
+## Validation Rules (( inert ))
 
 - Connection count < 20 on LinkedIn = likely wrong person, skip
 - Name mismatch between brain and API = skip, flag for review
@@ -298,7 +295,7 @@
 - Don't overwrite user-written assessments with API boilerplate
 - When in doubt: save raw data but don't update brain page
 
-## Report Storage
+## Report Storage (( inert ))
 
 After enrichment sweeps, save a report:
 - Number of entities processed
@@ -309,12 +306,13 @@
 
 This creates an audit trail for brain enrichment over time.
 
-## Anti-Patterns
-
-- Creating stub pages with no content
-- Enriching without checking brain first
-- Overwriting user's direct statements with API data
-- Creating pages for non-notable entities
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Creating stub pages with no content
+- [ ] Enriching without checking brain first
+- [ ] Overwriting user's direct statements with API data
+- [ ] Creating pages for non-notable entities
 
 ## Output Format
 
```
