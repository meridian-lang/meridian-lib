# Deviation: meeting_ingestion.meri

- Original: `meeting-ingestion/SKILL.md`
- Ported: `meeting_ingestion.meri`
- Tier: 3 (structural rewrite)
- Similarity: 49%
- Lines: 125 -> 127 (+65 / -63)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 1/10 inert (10% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 5 blocks, 26 lines

### Inert section details
- L88 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/meeting-ingestion/SKILL.md
+++ skills/meeting_ingestion.meri
@@ -29,97 +29,99 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Meeting page created with attendees, summary, key decisions, action items
-- EVERY attendee gets a people page (created or updated)
-- EVERY company discussed gets entity propagation
-- Timeline entries on ALL mentioned entities (timeline merge)
-- Meeting is NOT fully ingested until enrich runs for every entity
-- Back-links created bidirectionally
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Meeting page created with attendees, summary, key decisions, action items
+- [ ] EVERY attendee gets a people page (created or updated)
+- [ ] EVERY company discussed gets entity propagation
+- [ ] Timeline entries on ALL mentioned entities (timeline merge)
+- [ ] Meeting is NOT fully ingested until enrich runs for every entity
+- [ ] Back-links created bidirectionally
 
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+> > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
-Every attendee and company mentioned MUST get a back-link from their page to
-the meeting page. An unlinked mention is a broken brain.
+> Every attendee and company mentioned MUST get a back-link from their page to
+> the meeting page. An unlinked mention is a broken brain.
 
 ## Phases
 
-### Phase 1: Parse the transcript
+### Phase 1: Parse the transcript (( role: procedure ))
 
-Extract from the transcript:
-- Attendees (names, roles if available)
-- Date, time, duration
-- Key topics discussed
-- Decisions made
-- Action items with owners
-- Companies and projects mentioned
-
+use judgment to follow the Phase 1: Parse the transcript guidance:
+  Extract from the transcript:
+  item: Attendees (names, roles if available)
+  item: Date, time, duration
+  item: Key topics discussed
+  item: Decisions made
+  item: Action items with owners
+  item: Companies and projects mentioned
 ### Phase 2: Create meeting page
-
+  
 ```markdown
 # {Meeting Title} — {Date}
-
+  
 **Attendees:** {list with links to people pages}
 **Date:** {YYYY-MM-DD}
 **Duration:** {if available}
 
-## Summary
+## Summary (( inert ))
 {3-5 bullet key outcomes}
 
-## Key Decisions
+## Key Decisions (( inert ))
 {Decisions with context}
 
-## Action Items
+## Action Items (( inert ))
 {Tasks with owners and deadlines}
 
-## Discussion Notes
+## Discussion Notes (( inert ))
 {Structured notes by topic}
 ```
 
-### Phase 3: Attendee enrichment (MANDATORY)
+### Phase 3: Attendee enrichment (MANDATORY) (( role: procedure ))
 
-For EACH attendee:
-1. `gbrain search "{name}"` — does a people page exist?
-2. If NO → create via enrich skill (this is mandatory, not optional)
-3. If YES → update compiled truth with meeting context
-4. Add timeline entry on the person's page:
-   `gbrain timeline-add <person-slug> <date> "Attended <meeting-title>"`
-
-**Note (v0.10.1):** Once the meeting page is written via `gbrain put`, the
-auto-link post-hook automatically creates `attended` links from the meeting
-to each attendee whose page is referenced as `[Name](people/slug)`. You don't
-need to call `gbrain link` for attendees. You DO still need `gbrain timeline-add`
-for dated events (auto-link only handles links, not timeline entries).
-
-### Phase 4: Entity propagation (MANDATORY)
-
-For each company, project, or concept discussed:
-1. Check brain for existing page
-2. Create/update as needed
-3. Add timeline entry referencing the meeting
-4. Back-link from entity page to meeting page
-
-### Phase 5: Timeline merge
-
-The same event appears on ALL mentioned entities' timelines. If Alice met Bob at
-Acme Corp, the event goes on Alice's page, Bob's page, AND Acme Corp's page.
-
-### Phase 6: Sync
-
-`gbrain sync` to update the index.
-
+use judgment to follow the Phase 3: Attendee enrichment (MANDATORY) guidance:
+  For EACH attendee:
+  1. `gbrain search "{name}"` — does a people page exist?
+  2. If NO → create via enrich skill (this is mandatory, not optional)
+  3. If YES → update compiled truth with meeting context
+  4. Add timeline entry on the person's page:
+     `gbrain timeline-add <person-slug> <date> "Attended <meeting-title>"`
+  
+  **Note (v0.10.1):** Once the meeting page is written via `gbrain put`, the
+  auto-link post-hook automatically creates `attended` links from the meeting
+  to each attendee whose page is referenced as `[Name](people/slug)`. You don't
+  need to call `gbrain link` for attendees. You DO still need `gbrain timeline-add`
+  for dated events (auto-link only handles links, not timeline entries).
+### Phase 4: Entity propagation (MANDATORY) (( role: procedure ))
+  
+use judgment to follow the Phase 4: Entity propagation (MANDATORY) guidance:
+  For each company, project, or concept discussed:
+  1. Check brain for existing page
+  2. Create/update as needed
+  3. Add timeline entry referencing the meeting
+  4. Back-link from entity page to meeting page
+### Phase 5: Timeline merge (( role: procedure ))
+  
+use judgment to follow the Phase 5: Timeline merge guidance:
+  The same event appears on ALL mentioned entities' timelines. If Alice met Bob at
+  Acme Corp, the event goes on Alice's page, Bob's page, AND Acme Corp's page.
+### Phase 6: Sync (( role: procedure ))
+  
+use judgment to follow the Phase 6: Sync guidance:
+  `gbrain sync` to update the index.
 ## Output Format
 
 Meeting page created. Report: "Meeting ingested: {N} attendees enriched, {N} entities
 updated, {N} action items captured."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Creating the meeting page without enriching attendees
-- Skipping entity propagation ("I'll do that later")
-- Not merging timelines across all mentioned entities
-- Creating attendee stubs without meaningful content
-- Filing meeting pages without cross-linking to all participants
+!!! checklist (( ai-autonomy ))
+- [ ] Creating the meeting page without enriching attendees
+- [ ] Skipping entity propagation ("I'll do that later")
+- [ ] Not merging timelines across all mentioned entities
+- [ ] Creating attendee stubs without meaningful content
+- [ ] Filing meeting pages without cross-linking to all participants
 
```
