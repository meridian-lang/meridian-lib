# Deviation: media_ingest.meri

- Original: `media-ingest/SKILL.md`
- Ported: `media_ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 86%
- Lines: 122 -> 137 (+25 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L44 `Phase 3: Create brain page`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L88 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 5/7 (71% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=4, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=76

### Inert section details
- L8 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L44 `Phase 3: Create brain page`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L68 `Phase 4: Entity extraction and propagation`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L88 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L93 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/media-ingest/SKILL.md
+++ skills/media_ingest.meri
@@ -35,11 +35,11 @@
 
 # Media Ingest Skill
 
-Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
+> Ingest video, audio, PDF, book, screenshot, and GitHub repo content into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Every ingested media item has a brain page with analysis (not just a transcript dump)
@@ -50,11 +50,17 @@
 
 > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
+
+### Contract — steps (( role: reference ))
+
 Every mention of a person or company with a brain page MUST create a back-link.
 
 ## Phases
 
 ### Phase 1: Identify format and fetch
+
+
+### Phase 1: Identify format and fetch — steps (( role: reference ))
 
 | Format | Action |
 |--------|--------|
@@ -69,7 +75,7 @@
 
 Save the original file for provenance: `gbrain files upload-raw <file> --page <slug>`
 
-### Phase 3: Create brain page
+### Phase 3: Create brain page (( role: reference ))
 
 File by primary subject (not format). Use this template:
 
@@ -93,30 +99,39 @@
 {List with links to brain pages}
 ```
 
-### Phase 4: Entity extraction and propagation
+### Phase 4: Entity extraction and propagation (( role: reference ))
 
-For every person and company mentioned:
-1. Check brain for existing page
 2. Create/enrich if needed (delegate to enrich skill)
-3. Add back-link from entity page to this media page
 4. Add timeline entry on entity page
 
 A media item is NOT fully ingested until entity propagation is complete.
 
+
+### Phase 4: Entity extraction and propagation — steps
+
+For every person and company mentioned:
+1. Check brain for existing page
+
+### Phase 4: Entity extraction and propagation — steps 2
+
+3. Add back-link from entity page to this media page
 ### Phase 5: Sync
 
 `gbrain sync` to update the index.
 
-## Output Format
+## Output Format (( role: template ))
 
 Brain page created with summary, highlights, and entity cross-links. Report to user:
 "Ingested {title}: {N} entities detected, {N} pages updated."
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Dumping raw transcripts without analysis
 - Skipping entity extraction ("I'll do that separately")
-- Filing **raw ingest** by format (all videos in `media/videos/`) instead of by subject. Note: format-prefixed paths under `media/<format>/<slug>` ARE sanctioned for **synthesized one-of-one output** like book-mirror's `media/books/<slug>-personalized.md`. The anti-pattern is for raw ingest, not for sui generis synthesis. See `skills/_brain-filing-rules.md` "Sanctioned exception: synthesis output is sui generis."
 - Not preserving raw source files
 - Creating stub pages without meaningful content
 
+
+### Anti-Patterns — steps
+
+- Filing raw ingest by format (all videos in `media/videos/`) instead of by subject. Note: format-prefixed paths under `media/<format>/<slug>` ARE sanctioned for synthesized one-of-one output like book-mirror's `media/books/<slug>-personalized.md`. The anti-pattern is for raw ingest, not for sui generis synthesis. See `skills/_brain-filing-rules.md` "Sanctioned exception: synthesis output is sui generis."
```
