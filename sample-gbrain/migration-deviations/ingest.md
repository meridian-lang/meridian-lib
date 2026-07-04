# Deviation: ingest.meri

- Original: `ingest/SKILL.md`
- Ported: `ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 312 -> 312 (+19 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L8 `Contract`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L22 `Citation Requirements (MANDATORY)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L33 `Phases`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L47 `Entity Detection on Every Message`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L52 `Protocol`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L71 `What counts as notable`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L79 `What to capture from the user's own thinking`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L90 `Media Workflows`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L95 `Articles & Web Content`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L111 `Videos & Podcasts`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L134 `PDFs & Documents`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L147 `Screenshots & Images`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L159 `Meeting Transcripts`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L182 `Social Media Content`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L196 `Raw Source Preservation`: operational-content - Body contains command, table, checklist, or explicit AI-routing surface.
- L228 `Test Before Bulk`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L242 `Quality Rules`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L253 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L261 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L279 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections: 20/20 inert (100% inert ratio)
- Operational inert: 3
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=1, operational-procedure=1, reference-documentation=15, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `Contract`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L22 `Citation Requirements (MANDATORY)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L33 `Phases`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L47 `Entity Detection on Every Message`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L52 `Protocol`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L71 `What counts as notable`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L79 `What to capture from the user's own thinking`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L90 `Media Workflows`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L95 `Articles & Web Content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L111 `Videos & Podcasts`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L134 `PDFs & Documents`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L147 `Screenshots & Images`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L159 `Meeting Transcripts`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L182 `Social Media Content`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L196 `Raw Source Preservation`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L228 `Test Before Bulk`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L242 `Quality Rules`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L253 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L261 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L279 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/ingest/SKILL.md
+++ skills/ingest.meri
@@ -24,11 +24,11 @@
 
 # Ingest Skill
 
-Ingest meetings, articles, media, documents, and conversations into the brain.
+> Ingest meetings, articles, media, documents, and conversations into the brain.
 
 > **Filing rule:** Read `skills/_brain-filing-rules.md` before creating any new page.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 - Every fact written to a brain page carries an inline `[Source: ...]` citation with date and provenance.
 - Every entity mention creates a back-link from the entity's page to the page mentioning them (Iron Law).
@@ -42,7 +42,7 @@
 FROM that entity's page TO the page mentioning them. An unlinked mention is a
 broken brain. See `skills/_brain-filing-rules.md` for format.
 
-## Citation Requirements (MANDATORY)
+## Citation Requirements (MANDATORY) (( inert ))
 
 Every fact written to a brain page must carry an inline `[Source: ...]` citation.
 
@@ -53,7 +53,7 @@
 - **Social media:** `[Source: X/@handle, YYYY-MM-DD](URL)` (include link)
 - **Synthesis:** `[Source: compiled from {sources}]`
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 > **Router note:** This skill is a router. For specialized ingestion, see: idea-ingest, media-ingest, meeting-ingestion.
 
@@ -67,12 +67,12 @@
 5. **Back-link all entities.** Update EVERY mentioned entity's page with a back-link to this page (Iron Law).
 6. **Timeline merge.** The same event appears on ALL mentioned entities' timelines. If Alice met Bob at Acme Corp, the event goes on Alice's page, Bob's page, and Acme Corp's page.
 
-## Entity Detection on Every Message
+## Entity Detection on Every Message (( inert ))
 
 Production agents should detect entity mentions on EVERY inbound message. This is
 the signal detection loop that makes the brain compound over time.
 
-### Protocol
+### Protocol (( inert, role: procedure ))
 
 1. **Scan the message** for entity mentions: people, companies, concepts, original
    thinking. Fire on every message (no exceptions unless purely operational).
@@ -91,7 +91,7 @@
    alongside the response, not before it. The user shouldn't wait for brain writes
    to get an answer.
 
-### What counts as notable
+### What counts as notable (( inert ))
 
 - People the user interacts with or discusses (not random mentions)
 - Companies relevant to the user's work or interests
@@ -99,7 +99,7 @@
 - The user's own original thinking (ideas, theses, observations) -- highest value
 - See `skills/_brain-filing-rules.md` for the full notability gate
 
-### What to capture from the user's own thinking
+### What to capture from the user's own thinking (( inert ))
 
 Original thinking is the most valuable signal. Capture exact phrasing -- the user's
 language IS the insight. Don't paraphrase.
@@ -110,12 +110,12 @@
 - Contrarian positions with reasoning
 - Strong reactions to external stimuli (what triggered it and why)
 
-## Media Workflows
+## Media Workflows (( inert ))
 
 Content the user encounters should be captured in the brain. File by PRIMARY
 SUBJECT, not by format (see `skills/_brain-filing-rules.md`).
 
-### Articles & Web Content
+### Articles & Web Content (( inert ))
 
 **Input:** URL shared by user, or article mentioned in conversation.
 
@@ -131,7 +131,7 @@
 **Write to:** appropriate directory per filing rules (about a person -> `people/`,
 about a company -> `companies/`, reusable framework -> `concepts/`, raw data -> `sources/`)
 
-### Videos & Podcasts
+### Videos & Podcasts (( inert ))
 
 **Input:** URL (YouTube, podcast, etc.) or local audio/video file.
 
@@ -154,7 +154,7 @@
 - Verbatim quotes with real speaker names (not "speaker_0")
 - All entities extracted with context and back-linked
 
-### PDFs & Documents
+### PDFs & Documents (( inert ))
 
 **Input:** File path or URL.
 
@@ -167,7 +167,7 @@
 
 **Write to:** per filing rules (file by primary subject, not format).
 
-### Screenshots & Images
+### Screenshots & Images (( inert ))
 
 **Input:** Image file.
 
@@ -179,7 +179,7 @@
 
 **Write to:** depends on content -- route to the appropriate workflow above.
 
-### Meeting Transcripts
+### Meeting Transcripts (( inert ))
 
 **Input:** Transcript from meeting recording service, or manual notes.
 
@@ -202,7 +202,7 @@
 - Names tension or what was left unsaid
 - Captures actual dynamic, not performative summary
 
-### Social Media Content
+### Social Media Content (( inert ))
 
 **Input:** Tweet, thread, or social media post.
 
@@ -216,7 +216,7 @@
 **Write to:** `media/x/` for daily aggregation, or entity-specific directories
 if the post is primarily about a person/company.
 
-## Raw Source Preservation
+## Raw Source Preservation (( inert ))
 
 Every ingested item must have its raw source preserved for provenance.
 
@@ -248,7 +248,7 @@
 
 Use `put_raw_data` in gbrain to store raw API responses and metadata (JSON, not binary).
 
-## Test Before Bulk
+## Test Before Bulk (( inert ))
 
 When processing multiple items (batch video ingestion, bulk meeting processing, etc.):
 
@@ -262,7 +262,7 @@
 The marginal cost of testing 3 items first is near zero. The cost of cleaning
 up 100 bad pages is enormous.
 
-## Quality Rules
+## Quality Rules (( inert, role: invariants ))
 
 - Executive summary in compiled_truth must be updated, not just timeline appended
 - State section is REWRITTEN, not appended to. Current best understanding only.
@@ -273,7 +273,7 @@
 - Back-links: every entity mention creates a back-link (Iron Law)
 - Filing: file by primary subject, not format or source (see filing rules)
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Appending to State sections.** State is rewritten with the current best understanding on every update. Append-only State sections grow stale and contradictory.
 - **Ingesting without back-links.** An unlinked mention is a broken brain. Every entity mentioned must have a back-link from their page to the page mentioning them.
```
