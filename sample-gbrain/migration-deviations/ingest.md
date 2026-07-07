# Deviation: ingest.meri

- Original: `ingest/SKILL.md`
- Ported: `ingest.meri`
- Tier: 2 (light edits)
- Similarity: 68%
- Lines: 312 -> 383 (+147 / -76)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L27 `Citation Requirements (MANDATORY)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L55 `Entity Detection on Every Message`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L82 `What counts as notable`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L166 `PDFs & Documents`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L332 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L350 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 19/19 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=17, template=1, tools-metadata=1
- Judgment: 7 blocks, 0 lines

### Inert section details
- L8 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L27 `Citation Requirements (MANDATORY)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L55 `Entity Detection on Every Message`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L60 `Protocol`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L82 `What counts as notable`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L90 `What to capture from the user's own thinking`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L116 `Articles & Web Content`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L136 `Videos & Podcasts`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L166 `PDFs & Documents`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L179 `Screenshots & Images`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L195 `Meeting Transcripts`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L224 `Social Media Content`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L241 `Raw Source Preservation`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L282 `Test Before Bulk`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L299 `Quality Rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L317 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L332 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L350 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/ingest/SKILL.md
+++ skills/ingest.meri
@@ -24,25 +24,30 @@
 
 # Ingest Skill
 
-Ingest meetings, articles, media, documents, and conversations into the brain.
+> Ingest meetings, articles, media, documents, and conversations into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( role: reference ))
 
 - Every fact written to a brain page carries an inline `[Source: ...]` citation with date and provenance.
 - Every entity mention creates a back-link from the entity's page to the page mentioning them (Iron Law).
 - Raw sources are preserved for provenance via `gbrain files upload-raw` with automatic size routing.
+- Entity detection fires on every inbound message; notable entities get pages or updates.
+
+> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+
+
+### Contract — steps (( role: reference ))
+
+use judgment to follow the Contract — steps guidance:
 - State sections are rewritten with current best understanding, never appended to.
-- Entity detection fires on every inbound message; notable entities get pages or updates.
-
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
-
-Every mention of a person or company with a brain page MUST create a back-link
-FROM that entity's page TO the page mentioning them. An unlinked mention is a
-broken brain. See `skills/_brain-filing-rules.md` for format.
-
-## Citation Requirements (MANDATORY)
+
+### Contract — steps 2 (( role: reference ))
+
+Every mention of a person or company with a brain page MUST create a back-link FROM that entity's page TO the page mentioning them. An unlinked mention is a broken brain. See `skills/_brain-filing-rules.md` for format.
+
+## Citation Requirements (MANDATORY) (( role: reference ))
 
 Every fact written to a brain page must carry an inline `[Source: ...]` citation.
 
@@ -53,12 +58,11 @@
 - **Social media:** `[Source: X/@handle, YYYY-MM-DD](URL)` (include link)
 - **Synthesis:** `[Source: compiled from {sources}]`
 
-## Phases
+## Phases (( role: reference ))
 
 > **Router note:** This skill is a router. For specialized ingestion, see: idea-ingest, media-ingest, meeting-ingestion.
 
 1. **Parse the source.** Extract people, companies, dates, and events from the input.
-2. **For each entity mentioned:**
    - Read the entity's page from gbrain to check if it exists
    - If exists: update compiled_truth (rewrite State section with new info, don't append)
    - If new: check notability gate, then store the page in gbrain with the appropriate type and slug
@@ -67,31 +71,38 @@
 5. **Back-link all entities.** Update EVERY mentioned entity's page with a back-link to this page (Iron Law).
 6. **Timeline merge.** The same event appears on ALL mentioned entities' timelines. If Alice met Bob at Acme Corp, the event goes on Alice's page, Bob's page, and Acme Corp's page.
 
-## Entity Detection on Every Message
+
+### Phases — steps
+
+2. For each entity mentioned:
+## Entity Detection on Every Message (( role: reference ))
 
 Production agents should detect entity mentions on EVERY inbound message. This is
 the signal detection loop that makes the brain compound over time.
 
-### Protocol
+### Protocol (( role: reference ))
 
 1. **Scan the message** for entity mentions: people, companies, concepts, original
    thinking. Fire on every message (no exceptions unless purely operational).
-2. **For each entity detected:**
+4. **Don't block the conversation.** Entity detection and enrichment should happen
+   alongside the response, not before it. The user shouldn't wait for brain writes
+   to get an answer.
+
+
+### Protocol — steps (( role: reference ))
+
+2. For each entity detected:
    - `gbrain search "name"` -- does a page already exist?
-   - **If yes:** load context with `gbrain get <slug>`. Use the compiled truth to
+   - If yes: load context with `gbrain get <slug>`. Use the compiled truth to
      inform your response. Update the page if the message contains new information.
-   - **If no:** assess notability (see `skills/_brain-filing-rules.md`). If the entity
+   - If no: assess notability (see `skills/_brain-filing-rules.md`). If the entity
      is worth tracking, create a new page with `gbrain put <type/slug>` and populate
      with what you know.
-3. **After creating or updating pages:** sync to gbrain:
+> 3. **After creating or updating pages:** sync to gbrain:
    ```bash
    gbrain sync --no-pull --no-embed
    ```
-4. **Don't block the conversation.** Entity detection and enrichment should happen
-   alongside the response, not before it. The user shouldn't wait for brain writes
-   to get an answer.
-
-### What counts as notable
+### What counts as notable (( role: reference ))
 
 - People the user interacts with or discusses (not random mentions)
 - Companies relevant to the user's work or interests
@@ -99,23 +110,33 @@
 - The user's own original thinking (ideas, theses, observations) -- highest value
 - See `skills/_brain-filing-rules.md` for the full notability gate
 
-### What to capture from the user's own thinking
-
-Original thinking is the most valuable signal. Capture exact phrasing -- the user's
-language IS the insight. Don't paraphrase.
+### What to capture from the user's own thinking (( role: reference ))
 
 - Novel observations or theses
 - Frameworks, mental models, heuristics
 - Connections between ideas that others miss
+- Strong reactions to external stimuli (what triggered it and why)
+
+
+### What to capture from the user's own thinking — steps (( role: reference ))
+
+Original thinking is the most valuable signal. Capture exact phrasing -- the user's
+language IS the insight. Don't paraphrase.
+
+
+### What to capture from the user's own thinking — steps 2
+
+use judgment to follow the What to capture from the user's own thinking — steps 2 guidance:
 - Contrarian positions with reasoning
-- Strong reactions to external stimuli (what triggered it and why)
-
 ## Media Workflows
+
+
+### Media Workflows — steps
 
 Content the user encounters should be captured in the brain. File by PRIMARY
 SUBJECT, not by format (see `skills/_brain-filing-rules.md`).
 
-### Articles & Web Content
+### Articles & Web Content (( role: reference ))
 
 **Input:** URL shared by user, or article mentioned in conversation.
 
@@ -125,13 +146,17 @@
 3. Summarize: executive summary + key arguments (not a rehash)
 4. Extract entities: people, companies, concepts mentioned
 5. **Save raw source** for provenance (see Raw Source Preservation below)
+**Write to:** appropriate directory per filing rules (about a person -> `people/`,
+about a company -> `companies/`, reusable framework -> `concepts/`, raw data -> `sources/`)
+
+
+### Articles & Web Content — steps
+
+use judgment to follow the Articles & Web Content — steps guidance:
 6. Analyze for the user: don't just summarize. What's interesting given what you
    know about them? Flag connections, contradictions, content opportunities.
 
-**Write to:** appropriate directory per filing rules (about a person -> `people/`,
-about a company -> `companies/`, reusable framework -> `concepts/`, raw data -> `sources/`)
-
-### Videos & Podcasts
+### Videos & Podcasts (( role: reference ))
 
 **Input:** URL (YouTube, podcast, etc.) or local audio/video file.
 
@@ -139,12 +164,7 @@
 1. Get transcript -- speaker-diarized if possible (services like Diarize.io provide
    speaker-labeled, word-level timing)
 2. **Save raw transcript** (both JSON and human-readable TXT)
-3. Analyze: executive summary, key ideas, key quotes with speaker attribution,
-   notable stories/anecdotes, people and companies mentioned
 4. Extract and cross-reference all entities mentioned
-5. **HARD RULE:** every video/podcast brain page MUST link to the raw diarized
-   transcript. A page without transcript links is incomplete.
-
 **Write to:** `media/videos/` or `media/podcasts/` with back-links to all entities.
 
 **Quality bar:**
@@ -154,7 +174,19 @@
 - Verbatim quotes with real speaker names (not "speaker_0")
 - All entities extracted with context and back-linked
 
-### PDFs & Documents
+
+### Videos & Podcasts — steps
+
+use judgment to follow the Videos & Podcasts — steps guidance:
+3. Analyze: executive summary, key ideas, key quotes with speaker attribution,
+   notable stories/anecdotes, people and companies mentioned
+
+### Videos & Podcasts — steps 2
+
+5. HARD RULE: every video/podcast brain page MUST link to the raw diarized
+   transcript. A page without transcript links is incomplete.
+
+### PDFs & Documents (( role: reference ))
 
 **Input:** File path or URL.
 
@@ -167,19 +199,23 @@
 
 **Write to:** per filing rules (file by primary subject, not format).
 
-### Screenshots & Images
+### Screenshots & Images (( role: reference ))
 
 **Input:** Image file.
 
-**Process:**
-1. Analyze content (OCR for text-heavy images, description for photos)
 2. If tweet screenshot: extract text, author, date, route to social media workflow
 3. If article screenshot: extract text, route to article workflow
 4. If data/chart: extract data points, describe findings
 
 **Write to:** depends on content -- route to the appropriate workflow above.
 
-### Meeting Transcripts
+
+### Screenshots & Images — steps
+
+use judgment to follow the Screenshots & Images — steps guidance:
+> **Process:**
+1. Analyze content (OCR for text-heavy images, description for photos)
+### Meeting Transcripts (( role: reference ))
 
 **Input:** Transcript from meeting recording service, or manual notes.
 
@@ -187,13 +223,10 @@
 1. Pull full transcript (source of truth -- AI summaries are medium-low trust)
 2. **Save raw transcript** for provenance
 3. Write meeting page with YOUR analysis above the line, raw transcript below
-4. **Entity propagation (MANDATORY):** for each attendee and company discussed:
    - Update their brain page State section if new info surfaced
    - Append to their Timeline with link to the meeting page
    - Create page if person/company is notable and has no page yet
 5. A meeting is NOT fully ingested until all entity pages are updated
-
-**Write to:** `meetings/YYYY-MM-DD-short-description.md`
 
 **What makes a good meeting page:**
 - Reveals the real crux, not a bullet dump
@@ -202,7 +235,16 @@
 - Names tension or what was left unsaid
 - Captures actual dynamic, not performative summary
 
-### Social Media Content
+
+### Meeting Transcripts — steps
+
+4. Entity propagation (MANDATORY): for each attendee and company discussed:
+
+### Meeting Transcripts — steps 2
+
+Write to: `meetings/YYYY-MM-DD-short-description.md`
+
+### Social Media Content (( role: reference ))
 
 **Input:** Tweet, thread, or social media post.
 
@@ -211,25 +253,19 @@
 2. If images present: OCR via vision model for full text extraction
 3. Summarize: what's being said, why it matters, who's involved
 4. Extract entities and update brain pages
+
+### Social Media Content — steps
+
 5. Include direct link to the original post (MANDATORY for citations)
 
-**Write to:** `media/x/` for daily aggregation, or entity-specific directories
+Write to: `media/x/` for daily aggregation, or entity-specific directories
 if the post is primarily about a person/company.
 
-## Raw Source Preservation
-
-Every ingested item must have its raw source preserved for provenance.
-
-**Use `gbrain files upload-raw` for automatic size routing:**
-```bash
-gbrain files upload-raw <file> --page <page-slug> --type <type>
-```
-
-- **< 100 MB text/PDF**: stays in git (brain repo `.raw/` sidecar directories)
+## Raw Source Preservation (( role: reference ))
+
 - **>= 100 MB OR media** (video, audio, images): uploaded to cloud storage
   via TUS resumable upload, `.redirect.yaml` pointer left in the brain repo
 
-The `.redirect.yaml` pointer format:
 ```yaml
 target: supabase://brain-files/page-slug/filename.mp4
 bucket: brain-files
@@ -242,15 +278,31 @@
 type: transcript
 ```
 
-**Accessing stored files:**
+Use `put_raw_data` in gbrain to store raw API responses and metadata (JSON, not binary).
+
+
+### Raw Source Preservation — steps
+
+Every ingested item must have its raw source preserved for provenance.
+
+Use `gbrain files upload-raw` for automatic size routing:
+```bash
+gbrain files upload-raw <file> --page <page-slug> --type <type>
+```
+
+- < 100 MB text/PDF: stays in git (brain repo `.raw/` sidecar directories)
+
+### Raw Source Preservation — steps 2
+
+The `.redirect.yaml` pointer format:
+
+### Raw Source Preservation — steps 3
+
+> **Accessing stored files:**
 - `gbrain files signed-url <storage-path>` -- generate 1-hour signed URL for viewing/sharing
 - `gbrain files restore <dir>` -- download back to local from cloud storage
 
-Use `put_raw_data` in gbrain to store raw API responses and metadata (JSON, not binary).
-
-## Test Before Bulk
-
-When processing multiple items (batch video ingestion, bulk meeting processing, etc.):
+## Test Before Bulk (( role: reference ))
 
 1. **Test on 3-5 items first.** Run in test mode if available.
 2. **Read the actual output.** Is the quality good? Are titles compelling (not
@@ -262,10 +314,13 @@
 The marginal cost of testing 3 items first is near zero. The cost of cleaning
 up 100 bad pages is enormous.
 
-## Quality Rules
-
-- Executive summary in compiled_truth must be updated, not just timeline appended
-- State section is REWRITTEN, not appended to. Current best understanding only.
+
+### Test Before Bulk — steps (( role: reference ))
+
+When processing multiple items (batch video ingestion, bulk meeting processing, etc.):
+
+## Quality Rules (( role: reference ))
+
 - Timeline entries are reverse-chronological (newest first)
 - Every person/company mentioned gets a page if notable (see filing rules)
 - Link types: knows, works_at, invested_in, founded, met_at, discussed
@@ -273,14 +328,30 @@
 - Back-links: every entity mention creates a back-link (Iron Law)
 - Filing: file by primary subject, not format or source (see filing rules)
 
-## Anti-Patterns
-
-- **Appending to State sections.** State is rewritten with the current best understanding on every update. Append-only State sections grow stale and contradictory.
-- **Ingesting without back-links.** An unlinked mention is a broken brain. Every entity mentioned must have a back-link from their page to the page mentioning them.
-- **Skipping raw source preservation.** Every ingested item must have its raw source preserved. A brain page without provenance is unverifiable.
+
+### Quality Rules — steps (( role: reference ))
+
+- Executive summary in compiled_truth must be updated, not just timeline appended
+
+### Quality Rules — steps 2
+
+use judgment to follow the Quality Rules — steps 2 guidance:
+- State section is REWRITTEN, not appended to. Current best understanding only.
+## Anti-Patterns (( role: reference ))
+
 - **Bulk processing without sample test.** Test on 3-5 items first. Fix quality issues in the approach, not via one-off patches.
 - **Paraphrasing the user's original thinking.** The user's exact language IS the insight. Capture verbatim phrasing for ideas, theses, and frameworks.
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps guidance:
+- **Appending to State sections.** State is rewritten with the current best understanding on every update. Append-only State sections grow stale and contradictory.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+- An unlinked mention is a broken brain. Every entity mentioned must have a back-link from their page to the page mentioning them.
+- Every ingested item must have its raw source preserved. A brain page without provenance is unverifiable.
 ## Output Format
 
 ```
```
