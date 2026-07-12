# Deviation: meeting_ingestion.meri

- Original: `meeting-ingestion/SKILL.md`
- Ported: `meeting_ingestion.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 125 -> 136 (+26 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L25 `Phase 1: Parse the transcript`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Phase 2: Create meeting page`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L81 `Phase 4: Entity propagation (MANDATORY)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L89 `Phase 5: Timeline merge`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L98 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L103 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 72 non-blank ported lines
- Sections inert total: 8/9 (89% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=7, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=83

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L25 `Phase 1: Parse the transcript`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Phase 2: Create meeting page`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L57 `Phase 3: Attendee enrichment (MANDATORY)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L81 `Phase 4: Entity propagation (MANDATORY)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L89 `Phase 5: Timeline merge`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L98 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L103 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/meeting-ingestion/SKILL.md
+++ skills/meeting_ingestion.meri
@@ -29,7 +29,7 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Meeting page created with attendees, summary, key decisions, action items
@@ -41,12 +41,14 @@
 
 > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
-Every attendee and company mentioned MUST get a back-link from their page to
-the meeting page. An unlinked mention is a broken brain.
+
+### Contract — steps (( role: reference ))
+
+Every attendee and company mentioned MUST get a back-link from their page to the meeting page. An unlinked mention is a broken brain.
 
 ## Phases
 
-### Phase 1: Parse the transcript
+### Phase 1: Parse the transcript (( role: reference ))
 
 Extract from the transcript:
 - Attendees (names, roles if available)
@@ -56,7 +58,7 @@
 - Action items with owners
 - Companies and projects mentioned
 
-### Phase 2: Create meeting page
+### Phase 2: Create meeting page (( role: reference ))
 
 ```markdown
 # {Meeting Title} — {Date}
@@ -78,22 +80,31 @@
 {Structured notes by topic}
 ```
 
-### Phase 3: Attendee enrichment (MANDATORY)
+### Phase 3: Attendee enrichment (MANDATORY) (( role: reference ))
 
-For EACH attendee:
 1. `gbrain search "{name}"` — does a people page exist?
-2. If NO → create via enrich skill (this is mandatory, not optional)
 3. If YES → update compiled truth with meeting context
-4. Add timeline entry on the person's page:
-   `gbrain timeline-add <person-slug> <date> "Attended <meeting-title>"`
-
 **Note (v0.10.1):** Once the meeting page is written via `gbrain put`, the
 auto-link post-hook automatically creates `attended` links from the meeting
 to each attendee whose page is referenced as `[Name](people/slug)`. You don't
 need to call `gbrain link` for attendees. You DO still need `gbrain timeline-add`
 for dated events (auto-link only handles links, not timeline entries).
 
-### Phase 4: Entity propagation (MANDATORY)
+
+### Phase 3: Attendee enrichment (MANDATORY) — steps
+
+For EACH attendee:
+
+### Phase 3: Attendee enrichment (MANDATORY) — steps 2 (( role: reference ))
+
+2. If NO → create via enrich skill (this is mandatory, not optional)
+
+### Phase 3: Attendee enrichment (MANDATORY) — steps 3
+
+> 4. Add timeline entry on the person's page:
+   `gbrain timeline-add <person-slug> <date> "Attended <meeting-title>"`
+
+### Phase 4: Entity propagation (MANDATORY) (( role: reference ))
 
 For each company, project, or concept discussed:
 1. Check brain for existing page
@@ -101,7 +112,7 @@
 3. Add timeline entry referencing the meeting
 4. Back-link from entity page to meeting page
 
-### Phase 5: Timeline merge
+### Phase 5: Timeline merge (( role: reference ))
 
 The same event appears on ALL mentioned entities' timelines. If Alice met Bob at
 Acme Corp, the event goes on Alice's page, Bob's page, AND Acme Corp's page.
@@ -110,12 +121,12 @@
 
 `gbrain sync` to update the index.
 
-## Output Format
+## Output Format (( role: template ))
 
 Meeting page created. Report: "Meeting ingested: {N} attendees enriched, {N} entities
 updated, {N} action items captured."
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Creating the meeting page without enriching attendees
 - Skipping entity propagation ("I'll do that later")
```
