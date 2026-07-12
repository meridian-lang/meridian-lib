# Deviation: archive_crawler.meri

- Original: `archive-crawler/SKILL.md`
- Ported: `archive_crawler.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 321 -> 357 (+87 / -51)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L46 `What this is`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L69 `Manifest`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L190 `Plain text / HTML / Markdown`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L193 ``.mbox` (email archives)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L237 ``.zip` / `.tar` / `.tar.gz``: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L241 `Images`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L246 `Manifest template`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L326 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L337 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 241 non-blank ported lines
- Sections inert total: 16/18 (89% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=15, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=245

### Inert section details
- L12 `Safety gate (REQUIRED, no exceptions)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `What this is`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L57 `Source`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L69 `Manifest`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L100 `Phase 1: Inventory`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L117 `Phase 2: Crawl`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L136 `Phase 3: Ingest`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L190 `Plain text / HTML / Markdown`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L193 ``.mbox` (email archives)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L237 ``.zip` / `.tar` / `.tar.gz``: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L241 `Images`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L246 `Manifest template`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L293 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L311 `Related skills`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L326 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L337 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/archive-crawler/SKILL.md
+++ skills/archive_crawler.meri
@@ -26,12 +26,7 @@
 > this skill is **schema-generic**: it reads the user's filing rules from
 > the rules JSON instead of hardcoding any specific era / archive layout.
 
-## Safety gate (REQUIRED, no exceptions)
-
-archive-crawler refuses to run unless `archive-crawler.scan_paths:` is
-explicitly set in `gbrain.yml`. This is a deliberate safety fence against
-the agent over-scoping a scan and ingesting sensitive content (tax PDFs,
-medical records, credentials).
+## Safety gate (REQUIRED, no exceptions) (( role: reference ))
 
 ```yaml
 # gbrain.yml — the allow-list is mandatory
@@ -57,7 +52,15 @@
 This contract is enforced by `src/core/storage-config.ts` (mirrors the
 `db_tracked` / `db_only` allow-list pattern from v0.22.11 storage tiering).
 
-## What this is
+
+### Safety gate (REQUIRED, no exceptions) — steps (( role: reference ))
+
+archive-crawler refuses to run unless `archive-crawler.scan_paths:` is
+explicitly set in `gbrain.yml`. This is a deliberate safety fence against
+the agent over-scoping a scan and ingesting sensitive content (tax PDFs,
+medical records, credentials).
+
+## What this is (( role: reference ))
 
 Generic engine for exploring any tree of personal content within an
 explicit allow-list. Works on local mounts, Dropbox API targets,
@@ -66,18 +69,21 @@
 it interactively for review. Skips noise (system files, configs, binary
 blobs).
 
-## Concepts
-
-### Source
+## Concepts (( role: reference ))
+
+### Source (( role: reference ))
 
 A source is any tree of files to explore. Sources have:
 
 - **type**: `local` | `dropbox` | `backblaze` | `gmail-takeout` | `mbox` | `pst`
 - **root**: filesystem path, Dropbox path, B2 prefix, mbox path
-- **manifest**: a brain page tracking progress at
+
+### Source — steps (( role: reference ))
+
+- manifest: a brain page tracking progress at
   `projects/<archive-slug>/STATUS.md`
 
-### Manifest
+### Manifest (( role: reference ))
 
 Every archive exploration gets a manifest brain page that tracks:
 
@@ -91,7 +97,10 @@
 
 ### Gold filter
 
-Before showing anything to the user, apply the gold filter:
+
+### Gold filter — steps (( role: reference ))
+
+> Before showing anything to the user, apply the gold filter:
 
 | Keep (show) | Skip (note existence, don't show) |
 |-------------|-----------------------------------|
@@ -105,7 +114,7 @@
 
 ## Protocol
 
-### Phase 1: Inventory
+### Phase 1: Inventory (( role: reference ))
 
 When pointed at a new source:
 
@@ -113,41 +122,38 @@
 2. **Map the tree** — list folders + files + sizes + date ranges.
 3. **Classify folders** — group by likely content type (writing, email,
    code, photos, docs, system).
-4. **Create manifest** — write `projects/<archive-slug>/STATUS.md` with
-   the full inventory.
 5. **Propose priority queue** — rank folders by likely gold density.
 6. **Present to user** — show the map and proposed order. Let them
    override.
 
-### Phase 2: Crawl
+
+### Phase 1: Inventory — steps (( role: reference ))
+
+4. Create manifest — write `projects/<archive-slug>/STATUS.md` with
+   the full inventory.
+### Phase 2: Crawl (( role: reference ))
 
 Work through folders in priority order:
 
 1. **Read before showing** — open each candidate file, apply the gold
    filter, skip noise.
 2. **Show one at a time** — present gold items individually for review.
-3. **Capture exact reaction** — track the user's response in the
-   manifest using their exact words (per conventions/quality.md).
 4. **Ingest if worth keeping** — create a brain page immediately.
 5. **Update manifest** — mark item status after each interaction.
-6. **Never re-show** — check the manifest before presenting anything.
-
-### Phase 3: Ingest
-
-When an item is worth keeping, file it by **primary subject** per
-`_brain-filing-rules.md`:
-
-- User's own writing / ideas / origin-story content → `originals/<slug>.md`
-- Reflections / personal-life content → `personal/<slug>.md`
-- Product / business ideas → `ideas/<slug>.md`
+
+### Phase 2: Crawl — steps
+
+3. Capture exact reaction — track the user's response in the
+   manifest using their exact words (per conventions/quality.md).
+
+### Phase 2: Crawl — steps 2 (( role: reference ))
+
+6. Never re-show — check the manifest before presenting anything.
+
+### Phase 3: Ingest (( role: reference ))
+
 - Letters or threads about a specific person → `people/<person>/timeline`
   back-link plus the letter at `personal/<slug>.md` or `originals/<slug>.md`
-
-**The skill is schema-generic.** It does NOT bake in any specific
-era-folder structure (e.g., `originals/archive/` for pre-2003,
-`originals/yc-era/` for post-2019, etc.). The user's filing rules from
-`_brain-filing-rules.json` are read at runtime; the agent decides per-page
-where content lands within those sanctioned directories.
 
 Brain page format:
 
@@ -177,12 +183,31 @@
 [Raw source material below the line — full text]
 ```
 
-## File-type handlers
-
-### Plain text / HTML / Markdown
+
+### Phase 3: Ingest — steps (( role: reference ))
+
+When an item is worth keeping, file it by primary subject per
+`_brain-filing-rules.md`:
+
+- User's own writing / ideas / origin-story content → `originals/<slug>.md`
+- Reflections / personal-life content → `personal/<slug>.md`
+- Product / business ideas → `ideas/<slug>.md`
+
+### Phase 3: Ingest — steps 2
+
+use judgment to follow the Phase 3: Ingest — steps 2 guidance:
+**The skill is schema-generic.** It does NOT bake in any specific
+era-folder structure (e.g., `originals/archive/` for pre-2003,
+`originals/yc-era/` for post-2019, etc.). The user's filing rules from
+`_brain-filing-rules.json` are read at runtime; the agent decides per-page
+where content lands within those sanctioned directories.
+
+## File-type handlers (( role: reference ))
+
+### Plain text / HTML / Markdown (( role: reference ))
 Read directly. Strip HTML tags for display.
 
-### `.mbox` (email archives)
+### `.mbox` (email archives) (( role: reference ))
 
 ```python
 import mailbox
@@ -226,16 +251,16 @@
 readpst -o /tmp/pst-output /path/to/file.pst
 ```
 
-### `.zip` / `.tar` / `.tar.gz`
+### `.zip` / `.tar` / `.tar.gz` (( role: reference ))
 
 Extract to a temp dir, then recurse through the extracted tree.
 
-### Images
+### Images (( role: reference ))
 
 Note existence + metadata (filename, size, date). Don't show unless the
 user asks. Flag scans / portraits as potentially personal.
 
-## Manifest template
+## Manifest template (( role: reference ))
 
 ```markdown
 ---
@@ -282,29 +307,40 @@
 - Next: [what's queued]
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Running without `archive-crawler.scan_paths:` set. Hard refusal.
-  This is the safety contract — never bypass.
 - ❌ Hardcoding era-specific filing paths (e.g., `originals/archive/`,
   `originals/yc-era/`). Read filing rules at runtime instead.
-- ❌ Re-showing items already marked in the manifest. The user's time
-  is the scarcest resource.
 - ❌ Paraphrasing reactions. Exact words only.
 - ❌ Wrapping found content in lessons or takeaways. Let stories breathe.
 - ❌ Skipping back-links when content references people / companies who
   have brain pages. Iron Law per conventions/quality.md.
 
-## Related skills
+
+### Anti-Patterns — steps
+
+  This is the safety contract — never bypass.
+
+### Anti-Patterns — steps 2
+
+- ❌ Re-showing items already marked in the manifest. The user's time is the scarcest resource.
+## Related skills (( role: reference ))
+
+- `skills/idea-ingest/SKILL.md` — single-link-or-article ingest with
+  the same primary-subject filing rule
+
+### Related skills — steps
 
 - `skills/voice-note-ingest/SKILL.md` — same exact-phrasing pattern for
   audio capture
-- `skills/idea-ingest/SKILL.md` — single-link-or-article ingest with
-  the same primary-subject filing rule
+
+### Related skills — steps 2
+
 - `skills/conventions/quality.md` — citations, back-links, voice
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -315,7 +351,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
