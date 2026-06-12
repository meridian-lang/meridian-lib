# Deviation: meeting_ingestion.meri

- Original: `meeting-ingestion/SKILL.md`
- Ported: `meeting_ingestion.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 125 -> 125 (+11 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Unified diff

```diff
--- original-skills/meeting-ingestion/SKILL.md
+++ skills/meeting_ingestion.meri
@@ -29,7 +29,7 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Meeting page created with attendees, summary, key decisions, action items
@@ -46,7 +46,7 @@
 
 ## Phases
 
-### Phase 1: Parse the transcript
+### Phase 1: Parse the transcript (( inert, role: procedure ))
 
 Extract from the transcript:
 - Attendees (names, roles if available)
@@ -65,20 +65,20 @@
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
+### Phase 3: Attendee enrichment (MANDATORY) (( inert, role: procedure ))
 
 For EACH attendee:
 1. `gbrain search "{name}"` — does a people page exist?
@@ -93,7 +93,7 @@
 need to call `gbrain link` for attendees. You DO still need `gbrain timeline-add`
 for dated events (auto-link only handles links, not timeline entries).
 
-### Phase 4: Entity propagation (MANDATORY)
+### Phase 4: Entity propagation (MANDATORY) (( inert, role: procedure ))
 
 For each company, project, or concept discussed:
 1. Check brain for existing page
@@ -101,12 +101,12 @@
 3. Add timeline entry referencing the meeting
 4. Back-link from entity page to meeting page
 
-### Phase 5: Timeline merge
+### Phase 5: Timeline merge (( inert, role: procedure ))
 
 The same event appears on ALL mentioned entities' timelines. If Alice met Bob at
 Acme Corp, the event goes on Alice's page, Bob's page, AND Acme Corp's page.
 
-### Phase 6: Sync
+### Phase 6: Sync (( inert, role: procedure ))
 
 `gbrain sync` to update the index.
 
@@ -115,7 +115,7 @@
 Meeting page created. Report: "Meeting ingested: {N} attendees enriched, {N} entities
 updated, {N} action items captured."
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Creating the meeting page without enriching attendees
 - Skipping entity propagation ("I'll do that later")
```
