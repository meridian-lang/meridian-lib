# Deviation: archive_crawler.meri

- Original: `archive-crawler/SKILL.md`
- Ported: `archive_crawler.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 321 -> 346 (+52 / -27)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L12 `Safety gate (REQUIRED, no exceptions)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L43 `What this is`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L181 `Plain text / HTML / Markdown`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L184 ``.mbox` (email archives)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L228 ``.zip` / `.tar` / `.tar.gz``: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L232 `Images`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L237 `Manifest template`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L326 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 8/19 (42% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=7, template=1
- Judgment: 9 blocks, 0 lines

### Inert section details
- L12 `Safety gate (REQUIRED, no exceptions)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L43 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L181 `Plain text / HTML / Markdown`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L184 ``.mbox` (email archives)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L228 ``.zip` / `.tar` / `.tar.gz``: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L232 `Images`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L237 `Manifest template`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L326 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/archive-crawler/SKILL.md
+++ skills/archive_crawler.meri
@@ -26,7 +26,7 @@
 > this skill is **schema-generic**: it reads the user's filing rules from
 > the rules JSON instead of hardcoding any specific era / archive layout.
 
-## Safety gate (REQUIRED, no exceptions)
+## Safety gate (REQUIRED, no exceptions) (( inert ))
 
 archive-crawler refuses to run unless `archive-crawler.scan_paths:` is
 explicitly set in `gbrain.yml`. This is a deliberate safety fence against
@@ -57,7 +57,7 @@
 This contract is enforced by `src/core/storage-config.ts` (mirrors the
 `db_tracked` / `db_only` allow-list pattern from v0.22.11 storage tiering).
 
-## What this is
+## What this is (( inert ))
 
 Generic engine for exploring any tree of personal content within an
 explicit allow-list. Works on local mounts, Dropbox API targets,
@@ -66,18 +66,23 @@
 it interactively for review. Skips noise (system files, configs, binary
 blobs).
 
-## Concepts
+## Concepts (( inert ))
 
 ### Source
+use judgment to follow the Source guidance:
 
 A source is any tree of files to explore. Sources have:
 
 - **type**: `local` | `dropbox` | `backblaze` | `gmail-takeout` | `mbox` | `pst`
 - **root**: filesystem path, Dropbox path, B2 prefix, mbox path
-- **manifest**: a brain page tracking progress at
+
+#### Source — steps
+
+- manifest: a brain page tracking progress at
   `projects/<archive-slug>/STATUS.md`
 
 ### Manifest
+use judgment to follow the Manifest guidance:
 
 Every archive exploration gets a manifest brain page that tracks:
 
@@ -89,10 +94,14 @@
 4. **Priority queue** — what to explore next, ranked
 5. **Session log** — timestamped record of what was shown per session
 
-### Gold filter
-
-Before showing anything to the user, apply the gold filter:
-
+### Gold filter (( inert ))
+
+
+#### Gold filter — steps
+
+> Before showing anything to the user, apply the gold filter:
+
+!!! table (( ai-discretion ))
 | Keep (show) | Skip (note existence, don't show) |
 |-------------|-----------------------------------|
 | Personal writing (journals, letters, reflections, essays) | System files, configs, package.json, node_modules |
@@ -104,8 +113,10 @@
 | Emotional content (anger, love, grief, discovery) | |
 
 ## Protocol
+use judgment to follow the Protocol guidance:
 
 ### Phase 1: Inventory
+use judgment to follow the Phase 1: Inventory guidance:
 
 When pointed at a new source:
 
@@ -120,6 +131,7 @@
    override.
 
 ### Phase 2: Crawl
+use judgment to follow the Phase 2: Crawl guidance:
 
 Work through folders in priority order:
 
@@ -133,13 +145,8 @@
 6. **Never re-show** — check the manifest before presenting anything.
 
 ### Phase 3: Ingest
-
-When an item is worth keeping, file it by **primary subject** per
-`_brain-filing-rules.md`:
-
-- User's own writing / ideas / origin-story content → `originals/<slug>.md`
-- Reflections / personal-life content → `personal/<slug>.md`
-- Product / business ideas → `ideas/<slug>.md`
+use judgment to follow the Phase 3: Ingest guidance:
+
 - Letters or threads about a specific person → `people/<person>/timeline`
   back-link plus the letter at `personal/<slug>.md` or `originals/<slug>.md`
 
@@ -177,12 +184,21 @@
 [Raw source material below the line — full text]
 ```
 
-## File-type handlers
-
-### Plain text / HTML / Markdown
+
+#### Phase 3: Ingest — steps
+
+> When an item is worth keeping, file it by **primary subject** per
+> `_brain-filing-rules.md`:
+
+- User's own writing / ideas / origin-story content → `originals/<slug>.md`
+- Reflections / personal-life content → `personal/<slug>.md`
+- Product / business ideas → `ideas/<slug>.md`
+## File-type handlers (( inert ))
+
+### Plain text / HTML / Markdown (( inert ))
 Read directly. Strip HTML tags for display.
 
-### `.mbox` (email archives)
+### `.mbox` (email archives) (( inert ))
 
 ```python
 import mailbox
@@ -226,16 +242,16 @@
 readpst -o /tmp/pst-output /path/to/file.pst
 ```
 
-### `.zip` / `.tar` / `.tar.gz`
+### `.zip` / `.tar` / `.tar.gz` (( inert ))
 
 Extract to a temp dir, then recurse through the extracted tree.
 
-### Images
+### Images (( inert ))
 
 Note existence + metadata (filename, size, date). Don't show unless the
 user asks. Flag scans / portraits as potentially personal.
 
-## Manifest template
+## Manifest template (( inert ))
 
 ```markdown
 ---
@@ -282,7 +298,8 @@
 - Next: [what's queued]
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Running without `archive-crawler.scan_paths:` set. Hard refusal.
   This is the safety contract — never bypass.
@@ -296,15 +313,23 @@
   have brain pages. Iron Law per conventions/quality.md.
 
 ## Related skills
+use judgment to follow the Related skills guidance:
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
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -315,7 +340,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
