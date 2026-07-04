# Deviation: meeting_ingestion.meri

- Original: `meeting-ingestion/SKILL.md`
- Ported: `meeting_ingestion.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 125 -> 125 (+14 / -14)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L21 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L23 `Phase 1: Parse the transcript`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L33 `Phase 2: Create meeting page`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L55 `Phase 3: Attendee enrichment (MANDATORY)`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L70 `Phase 4: Entity propagation (MANDATORY)`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L78 `Phase 5: Timeline merge`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L83 `Phase 6: Sync`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L87 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L92 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 10/10 inert (100% inert ratio)
- Operational inert: 7
- Unclassified inert: 0
- Inert categories: operational-procedure=7, reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L21 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L23 `Phase 1: Parse the transcript`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L33 `Phase 2: Create meeting page`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L55 `Phase 3: Attendee enrichment (MANDATORY)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L70 `Phase 4: Entity propagation (MANDATORY)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L78 `Phase 5: Timeline merge`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L83 `Phase 6: Sync`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L87 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L92 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

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
@@ -44,9 +44,9 @@
 Every attendee and company mentioned MUST get a back-link from their page to
 the meeting page. An unlinked mention is a broken brain.
 
-## Phases
+## Phases (( inert, role: procedure ))
 
-### Phase 1: Parse the transcript
+### Phase 1: Parse the transcript (( inert, role: procedure ))
 
 Extract from the transcript:
 - Attendees (names, roles if available)
@@ -56,7 +56,7 @@
 - Action items with owners
 - Companies and projects mentioned
 
-### Phase 2: Create meeting page
+### Phase 2: Create meeting page (( inert, role: procedure ))
 
 ```markdown
 # {Meeting Title} — {Date}
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
@@ -101,21 +101,21 @@
 3. Add timeline entry referencing the meeting
 4. Back-link from entity page to meeting page
 
-### Phase 5: Timeline merge
+### Phase 5: Timeline merge (( inert, role: procedure ))
 
 The same event appears on ALL mentioned entities' timelines. If Alice met Bob at
 Acme Corp, the event goes on Alice's page, Bob's page, AND Acme Corp's page.
 
-### Phase 6: Sync
+### Phase 6: Sync (( inert, role: procedure ))
 
 `gbrain sync` to update the index.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Meeting page created. Report: "Meeting ingested: {N} attendees enriched, {N} entities
 updated, {N} action items captured."
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Creating the meeting page without enriching attendees
 - Skipping entity propagation ("I'll do that later")
```
