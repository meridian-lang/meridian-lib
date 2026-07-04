# Deviation: enrich.meri

- Original: `enrich/SKILL.md`
- Ported: `enrich.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 350 -> 350 (+43 / -43)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L23 `Philosophy`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L29 `Citation Requirements (MANDATORY)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L35 `When To Enrich`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L37 `Primary triggers`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L44 `Do NOT enrich`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L50 `Enrichment Tiers`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L60 `The Enrichment Protocol (7 Steps)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L62 `Step 1: Identify entities`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L66 `Step 2: Check brain state`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L73 `Step 3: Extract signal from source`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L87 `Step 4: External data source lookups`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L121 `Step 5: Save raw data (preserves provenance)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L136 `Step 6: Write to brain`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L155 `Person page template`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L217 `Company page template`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L244 `Step 7: Cross-reference`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L257 `Bulk Enrichment Rules`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L266 `Validation Rules`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L274 `Report Storage`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L285 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L292 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L313 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections: 23/25 inert (92% inert ratio)
- Operational inert: 4
- Unclassified inert: 0
- Inert categories: operational-content=3, operational-procedure=1, reference-documentation=17, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L23 `Philosophy`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L29 `Citation Requirements (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `When To Enrich`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L37 `Primary triggers`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L44 `Do NOT enrich`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L50 `Enrichment Tiers`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L60 `The Enrichment Protocol (7 Steps)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L62 `Step 1: Identify entities`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L66 `Step 2: Check brain state`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L73 `Step 3: Extract signal from source`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L87 `Step 4: External data source lookups`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L121 `Step 5: Save raw data (preserves provenance)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L136 `Step 6: Write to brain`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L155 `Person page template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L217 `Company page template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L244 `Step 7: Cross-reference`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L257 `Bulk Enrichment Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L266 `Validation Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L274 `Report Storage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L285 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L292 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L313 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every enriched page has compiled truth (State section) with inline citations
@@ -47,34 +47,34 @@
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
 broken brain. See `skills/_brain-filing-rules.md` for format.
 
-## Philosophy
+## Philosophy (( inert ))
 
 A brain page should read like an intelligence dossier, not a LinkedIn scrape.
 Facts are table stakes. Texture is the value -- what do they believe, what are
 they building, what makes them tick, where are they headed.
 
-## Citation Requirements (MANDATORY)
+## Citation Requirements (MANDATORY) (( inert ))
 
 > **Convention:** see `skills/conventions/quality.md` for citation formats and source precedence.
 
 When sources conflict, note the contradiction with both citations.
 
-## When To Enrich
-
-### Primary triggers
+## When To Enrich (( inert ))
+
+### Primary triggers (( inert, role: applicability ))
 - User mentions an entity in conversation
 - Entity appears in a meeting transcript or email
 - New contact appears with significant context
 - Entity makes news or has a major event
 - Any ingest pipeline encounters a notable entity
 
-### Do NOT enrich
+### Do NOT enrich (( inert ))
 - Random mentions with no relationship signal
 - Bot/spam accounts
 - Entities with no substantive connection to the user's work
 - Same page enriched within the past week (unless new signal warrants it)
 
-## Enrichment Tiers
+## Enrichment Tiers (( inert ))
 
 Scale enrichment to importance. Don't waste API calls on low-value entities.
 
@@ -84,20 +84,20 @@
 | 2 (notable) | Occasional interactions, industry figures | Moderate | Web research + social + brain cross-ref |
 | 3 (minor) | Worth tracking, not critical | Light | Brain cross-ref + social lookup if handle known |
 
-## The Enrichment Protocol (7 Steps)
-
-### Step 1: Identify entities
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
+### Step 3: Extract signal from source (( inert ))
 
 Don't just capture facts. Capture texture:
 
@@ -111,7 +111,7 @@
 | Ascending, plateauing, pivoting? | Trajectory section |
 | Role, company, funding, location | State section (hard facts) |
 
-### Step 4: External data source lookups
+### Step 4: External data source lookups (( inert ))
 
 Priority order -- stop when you have enough signal for the entity's tier.
 
@@ -145,7 +145,7 @@
 | Social media | Platform APIs, web scraping | 1-3 |
 | Meeting history | Calendar/meeting transcript tools | 1-2 |
 
-### Step 5: Save raw data (preserves provenance)
+### Step 5: Save raw data (preserves provenance) (( inert ))
 
 Store raw API responses via `put_raw_data` in gbrain:
 ```json
@@ -160,7 +160,7 @@
 Raw data preserves provenance. If the compiled truth is ever questioned,
 the raw data shows exactly what the API returned.
 
-### Step 6: Write to brain
+### Step 6: Write to brain (( inert ))
 
 #### CREATE path
 
@@ -179,7 +179,7 @@
 4. Flag contradictions between new signal and existing compiled truth
 5. Don't overwrite user-written assessments with API boilerplate
 
-#### Person page template
+#### Person page template (( inert ))
 
 ```markdown
 ---
@@ -201,47 +201,47 @@
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
@@ -256,19 +256,19 @@
 
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
@@ -281,16 +281,16 @@
 field in the put_page response (`{ created, removed, errors }`).
 Timeline entries still need explicit `gbrain timeline-add` calls.
 
-## Bulk Enrichment Rules
-
-- **Test on 3-5 entities first.** Read actual output. Check quality.
+## Bulk Enrichment Rules (( inert ))
+
+- Test on 3-5 entities first. Read actual output. Check quality.
 - Only proceed to bulk after test shots pass your quality bar.
 - 3+ entities from one source -> batch process or spawn sub-agent
 - Throttle API calls. Respect rate limits.
 - Commit every 5-10 entities during bulk runs.
 - Save a report after bulk enrichment (see Report Storage below).
 
-## Validation Rules
+## Validation Rules (( inert ))
 
 - Connection count < 20 on LinkedIn = likely wrong person, skip
 - Name mismatch between brain and API = skip, flag for review
@@ -298,7 +298,7 @@
 - Don't overwrite user-written assessments with API boilerplate
 - When in doubt: save raw data but don't update brain page
 
-## Report Storage
+## Report Storage (( inert ))
 
 After enrichment sweeps, save a report:
 - Number of entities processed
@@ -309,14 +309,14 @@
 
 This creates an audit trail for brain enrichment over time.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Creating stub pages with no content
 - Enriching without checking brain first
 - Overwriting user's direct statements with API data
 - Creating pages for non-notable entities
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 An enriched person page contains:
 - **Frontmatter** with type, tags, company, relationship, and contact fields
```
