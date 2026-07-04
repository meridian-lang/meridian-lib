# Deviation: meeting_ingestion.meri

- Original: `meeting-ingestion/SKILL.md`
- Ported: `meeting_ingestion.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 125 -> 138 (+20 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L99 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/10 (10% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 7 blocks, 0 lines

### Inert section details
- L99 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/meeting-ingestion/SKILL.md
+++ skills/meeting_ingestion.meri
@@ -29,7 +29,8 @@
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Meeting page created with attendees, summary, key decisions, action items
@@ -45,8 +46,10 @@
 the meeting page. An unlinked mention is a broken brain.
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 ### Phase 1: Parse the transcript
+use judgment to follow the Phase 1: Parse the transcript guidance:
 
 Extract from the transcript:
 - Attendees (names, roles if available)
@@ -57,6 +60,7 @@
 - Companies and projects mentioned
 
 ### Phase 2: Create meeting page
+use judgment to follow the Phase 2: Create meeting page guidance:
 
 ```markdown
 # {Meeting Title} — {Date}
@@ -79,19 +83,26 @@
 ```
 
 ### Phase 3: Attendee enrichment (MANDATORY)
+use judgment to follow the Phase 3: Attendee enrichment (MANDATORY) guidance:
 
-For EACH attendee:
 1. `gbrain search "{name}"` — does a people page exist?
 2. If NO → create via enrich skill (this is mandatory, not optional)
 3. If YES → update compiled truth with meeting context
-4. Add timeline entry on the person's page:
-   `gbrain timeline-add <person-slug> <date> "Attended <meeting-title>"`
-
 **Note (v0.10.1):** Once the meeting page is written via `gbrain put`, the
 auto-link post-hook automatically creates `attended` links from the meeting
 to each attendee whose page is referenced as `[Name](people/slug)`. You don't
 need to call `gbrain link` for attendees. You DO still need `gbrain timeline-add`
 for dated events (auto-link only handles links, not timeline entries).
+
+
+#### Phase 3: Attendee enrichment (MANDATORY) — steps
+
+For EACH attendee:
+
+#### Phase 3: Attendee enrichment (MANDATORY) — steps 2
+
+> 4. Add timeline entry on the person's page:
+   `gbrain timeline-add <person-slug> <date> "Attended <meeting-title>"`
 
 ### Phase 4: Entity propagation (MANDATORY)
 
@@ -102,6 +113,7 @@
 4. Back-link from entity page to meeting page
 
 ### Phase 5: Timeline merge
+use judgment to follow the Phase 5: Timeline merge guidance:
 
 The same event appears on ALL mentioned entities' timelines. If Alice met Bob at
 Acme Corp, the event goes on Alice's page, Bob's page, AND Acme Corp's page.
@@ -110,12 +122,13 @@
 
 `gbrain sync` to update the index.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Meeting page created. Report: "Meeting ingested: {N} attendees enriched, {N} entities
 updated, {N} action items captured."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Creating the meeting page without enriching attendees
 - Skipping entity propagation ("I'll do that later")
```
