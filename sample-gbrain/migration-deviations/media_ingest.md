# Deviation: media_ingest.meri

- Original: `media-ingest/SKILL.md`
- Ported: `media_ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 122 -> 137 (+23 / -8)

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
- L90 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/8 (12% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 5 blocks, 0 lines

### Inert section details
- L90 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/media-ingest/SKILL.md
+++ skills/media_ingest.meri
@@ -35,11 +35,12 @@
 
 # Media Ingest Skill
 
-Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
+> Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Every ingested media item has a brain page with analysis (not just a transcript dump)
@@ -53,9 +54,14 @@
 Every mention of a person or company with a brain page MUST create a back-link.
 
 ## Phases
+use judgment to follow the Phases guidance:
 
-### Phase 1: Identify format and fetch
+### Phase 1: Identify format and fetch (( inert, role: procedure ))
 
+
+#### Phase 1: Identify format and fetch — steps
+
+!!! table (( ai-discretion ))
 | Format | Action |
 |--------|--------|
 | YouTube/video URL | Fetch transcript (Whisper, transcription service, or captions) |
@@ -70,6 +76,7 @@
 Save the original file for provenance: `gbrain files upload-raw <file> --page <slug>`
 
 ### Phase 3: Create brain page
+use judgment to follow the Phase 3: Create brain page guidance:
 
 File by primary subject (not format). Use this template:
 
@@ -94,25 +101,33 @@
 ```
 
 ### Phase 4: Entity extraction and propagation
+use judgment to follow the Phase 4: Entity extraction and propagation guidance:
 
-For every person and company mentioned:
-1. Check brain for existing page
 2. Create/enrich if needed (delegate to enrich skill)
-3. Add back-link from entity page to this media page
 4. Add timeline entry on entity page
 
 A media item is NOT fully ingested until entity propagation is complete.
 
+
+#### Phase 4: Entity extraction and propagation — steps
+
+For every person and company mentioned:
+1. Check brain for existing page
+
+#### Phase 4: Entity extraction and propagation — steps 2
+
+3. Add back-link from entity page to this media page
 ### Phase 5: Sync
 
 `gbrain sync` to update the index.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Brain page created with summary, highlights, and entity cross-links. Report to user:
 "Ingested {title}: {N} entities detected, {N} pages updated."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Dumping raw transcripts without analysis
 - Skipping entity extraction ("I'll do that separately")
```
