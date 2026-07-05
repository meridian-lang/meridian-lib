# Deviation: maintain.meri

- Original: `maintain/SKILL.md`
- Ported: `maintain.meri`
- Tier: 2 (light edits)
- Similarity: 65%
- Lines: 431 -> 567 (+242 / -106)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L75 `Orphan pages`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L80 `Dead links`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L84 `Missing cross-references`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L297 `Tag consistency`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L403 `Heartbeat Integration`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L436 `Stale compiled truth detection`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L487 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L520 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 25/27 (93% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=23, template=1, tools-metadata=1
- Judgment: 7 blocks, 0 lines

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L20 `Autonomous path (v0.36.4.0) — when you want to reach a target score`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L59 `Manual path`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L67 `Stale pages`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L75 `Orphan pages`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L80 `Dead links`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L84 `Missing cross-references`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L88 `Link graph extraction`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L108 `Dream cycle (v0.23): synthesize + patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L222 `Autopilot check`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L265 `Back-link enforcement`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L276 `Filing rule violations`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L287 `Citation audit`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L297 `Tag consistency`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L301 `Graph population (v0.10.3+)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L339 `Embedding freshness`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L360 `File storage health`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L378 `Benchmark Testing`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L403 `Heartbeat Integration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L436 `Stale compiled truth detection`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L442 `Report Storage`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L460 `Quality Rules`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L469 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L487 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L520 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/maintain/SKILL.md
+++ skills/maintain.meri
@@ -37,91 +37,142 @@
 
 # Maintain Skill
 
-Periodic brain health checks and cleanup.
-
-## Contract
+> Periodic brain health checks and cleanup.
+
+## Contract (( role: reference ))
 
 This skill guarantees:
 - All health dimensions are checked (stale, orphan, dead links, cross-refs, backlinks, citations, filing, tags)
-- Each issue found has a specific fix action
 - Back-link iron law is enforced
 - Citation format is validated against the standard
 - Results are reported with counts per dimension
 
+
+### Contract — steps
+
+- Each issue found has a specific fix action
 ## Phases
 
-### Autonomous path (v0.36.4.0) — when you want to reach a target score
-
-If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
-one-command loop over walking each dimension by hand:
+### Autonomous path (v0.36.4.0) — when you want to reach a target score (( role: reference ))
+
+`--remediation-plan` prints a dependency-ordered list (sync before extract,
+embed after consolidate, etc.) with per-step `est_seconds` and `est_usd_cost`.
+Use the per-dimension walk below (Phase 2 onward) when:
+- The user explicitly asks for a dimension-by-dimension audit
+- A specific dimension needs manual judgment that the auto path skips
+
+
+### Autonomous path (v0.36.4.0) — when you want to reach a target score — steps
+
+> If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
+> one-command loop over walking each dimension by hand:
 
 ```bash
 gbrain doctor --remediation-plan --json              # preview what would run
 gbrain doctor --remediate --yes --target-score 90 --max-usd 5
 ```
 
-`--remediation-plan` prints a dependency-ordered list (sync before extract,
-embed after consolidate, etc.) with per-step `est_seconds` and `est_usd_cost`.
+
+### Autonomous path (v0.36.4.0) — when you want to reach a target score — steps 2
+
+use judgment to follow the Autonomous path (v0.36.4.0) — when you want to reach a target score — steps 2 guidance:
 `--remediate` walks the plan, submitting each step as a Minion job, re-checking
 score between every step. `--max-usd N` is a hard cost cap — submission refuses
 when the plan would exceed the cap (prevents synthesize loops from burning
 Anthropic credits unattended).
 
+
+### Autonomous path (v0.36.4.0) — when you want to reach a target score — steps 3
+
 When the target score is unreachable for the brain (empty brain with no entity
 pages → `graph_coverage` caps at 70; unconfigured embedding key → caps at 60),
 the command bails with a list of what's missing rather than looping.
 
-Use the per-dimension walk below (Phase 2 onward) when:
-- The user explicitly asks for a dimension-by-dimension audit
+
+### Autonomous path (v0.36.4.0) — when you want to reach a target score — steps 4
+
 - You're investigating why score is stuck below `--remediate`'s ceiling
-- A specific dimension needs manual judgment that the auto path skips
-
-### Manual path
-
-1. **Run health check.** Check gbrain health to get the dashboard.
+### Manual path (( role: reference ))
+
 2. **Check each dimension:**
 
-### Stale pages
+
+### Manual path — steps
+
+1. Check gbrain health to get the dashboard.
+### Stale pages (( role: reference ))
 Pages where compiled_truth is older than the latest timeline entry. The assessment hasn't been updated to reflect recent evidence.
+
+### Stale pages — steps
+
 - Check the health output for stale page count
 - For each stale page: read the page from gbrain, review timeline, determine if compiled_truth needs rewriting
 
-### Orphan pages
+### Orphan pages (( role: reference ))
 Pages with zero inbound links. Nobody references them.
 - Review orphans: are they genuinely isolated or just missing links?
 - Add links in gbrain from related pages or flag for deletion
 
-### Dead links
+### Dead links (( role: reference ))
 Links pointing to pages that don't exist.
 - Remove dead links in gbrain
 
-### Missing cross-references
+### Missing cross-references (( role: reference ))
 Pages that mention entity names but don't have formal links.
 - Read compiled_truth from gbrain, extract entity mentions, create links in gbrain
 
-### Link graph extraction
-If link_count is 0 or low relative to page_count, run batch extraction:
-```bash
-gbrain extract links --dir ~/brain
-```
+### Link graph extraction (( role: reference ))
 This scans all markdown files for entity references, See Also sections, and
 frontmatter fields, then creates typed links in the database.
 
+
+### Link graph extraction — steps
+
+> If link_count is 0 or low relative to page_count, run batch extraction:
+```bash
+gbrain extract links --dir ~/brain
+```
 ### Timeline extraction
-If timeline_entry_count is 0, extract structured timeline from markdown:
+
+### Timeline extraction — steps
+
+> If timeline_entry_count is 0, extract structured timeline from markdown:
 ```bash
 gbrain extract timeline --dir ~/brain
 ```
 
-### Dream cycle (v0.23): synthesize + patterns
+### Dream cycle (v0.23): synthesize + patterns (( role: reference ))
+
+```
+lint -> backlinks -> sync -> synthesize -> extract -> patterns -> embed -> orphans
+```
+
+**Patterns phase:** runs after `extract` (so the graph state is fresh).
+Reads recent reflections within `dream.patterns.lookback_days` (default 30),
+runs a single Sonnet pass to surface recurring themes, and writes pattern
+pages to `wiki/personal/patterns/<theme>` when ≥`dream.patterns.min_evidence`
+(default 3) reflections support a pattern.
+
+**Quality bar (Iron Law for synthesis):**
+1. Quote the user verbatim. Do not paraphrase memorable phrasings.
+3. Slug discipline: lowercase alphanumeric and hyphens only. NO underscores, NO file extensions.
+Each entry is auto-wrapped as a word-boundary regex (e.g. `medical` matches
+"medical advice" but NOT "comedical"). Power users may pass full regex.
+
+**Auto-commit deferred to v1.1:** v1 writes files to `brain_dir` but does NOT
+`git add` / `commit` / `push`. Either commit yourself or let `gbrain autopilot`
+handle it.
+Parses `- **YYYY-MM-DD** | Source — Summary` and `### YYYY-MM-DD — Title` formats.
+
+### Dream cycle (v0.23): synthesize + patterns — steps
 
 `gbrain dream` runs the full 8-phase maintenance cycle:
 
-```
-lint -> backlinks -> sync -> synthesize -> extract -> patterns -> embed -> orphans
-```
-
-The two new phases consolidate yesterday's conversations into long-term memory:
+
+### Dream cycle (v0.23): synthesize + patterns — steps 2
+
+use judgment to follow the Dream cycle (v0.23): synthesize + patterns — steps 2 guidance:
+> The two new phases consolidate yesterday's conversations into long-term memory:
 
 **Synthesize phase:** reads transcripts from `dream.synthesize.session_corpus_dir`,
 runs a cheap Haiku verdict (cached in `dream_verdicts`) to filter routine
@@ -132,18 +183,19 @@
 `pages.updated_at` — that would pick up unrelated writes) and reverse-renders
 each new page from DB → markdown on disk.
 
-**Patterns phase:** runs after `extract` (so the graph state is fresh).
-Reads recent reflections within `dream.patterns.lookback_days` (default 30),
-runs a single Sonnet pass to surface recurring themes, and writes pattern
-pages to `wiki/personal/patterns/<theme>` when ≥`dream.patterns.min_evidence`
-(default 3) reflections support a pattern.
-
-**Quality bar (Iron Law for synthesis):**
-1. Quote the user verbatim. Do not paraphrase memorable phrasings.
+
+### Dream cycle (v0.23): synthesize + patterns — steps 3
+
 2. Cross-reference compulsively: every new page MUST have at least one wikilink.
-3. Slug discipline: lowercase alphanumeric and hyphens only. NO underscores, NO file extensions.
+
+### Dream cycle (v0.23): synthesize + patterns — steps 4
+
 4. Edited transcripts produce NEW slugs (content-hash suffix changes) — never silently overwrite.
 
+
+### Dream cycle (v0.23): synthesize + patterns — steps 5
+
+use judgment to follow the Dream cycle (v0.23): synthesize + patterns — steps 5 guidance:
 **Trust boundary (`allowed_slug_prefixes`):** the synthesis subagent runs with an
 explicit allow-list of write paths sourced from `_brain-filing-rules.json`'s
 `dream_synthesize_paths.globs`. Even on prompt-injection success, the subagent
@@ -154,19 +206,33 @@
 **Idempotency + privacy:** transcripts are keyed by `(file_path, content_hash)`,
 so re-running on the same content is a no-op. `dream.synthesize.exclude_patterns`
 (default `["medical", "therapy"]`) filters out transcripts before any LLM call.
-Each entry is auto-wrapped as a word-boundary regex (e.g. `medical` matches
-"medical advice" but NOT "comedical"). Power users may pass full regex.
-
-**Cooldown:** the cycle's spend cap. `dream.synthesize.cooldown_hours` (default
+
+### Dream cycle (v0.23): synthesize + patterns — steps 6
+
+Cooldown: the cycle's spend cap. `dream.synthesize.cooldown_hours` (default
+
+### Dream cycle (v0.23): synthesize + patterns — steps 7
+
+use judgment to follow the Dream cycle (v0.23): synthesize + patterns — steps 7 guidance:
 12) means at most ~2 synthesize runs per day under autopilot. The completion
 timestamp is stored in `dream.synthesize.last_completion_ts` and is written
 ONLY on successful runs (not on skipped/failed). Explicit `--input` /
 `--date` / `--from` / `--to` invocations bypass cooldown.
 
-**`--dry-run` semantics:** runs the cheap Haiku significance filter (caches
+
+### Dream cycle (v0.23): synthesize + patterns — steps 8
+
+`--dry-run` semantics: runs the cheap Haiku significance filter (caches
 verdicts) but skips the Sonnet synthesis pass. NOT zero LLM calls.
 
+
+### Dream cycle (v0.23): synthesize + patterns — steps 9
+
+use judgment to follow the Dream cycle (v0.23): synthesize + patterns — steps 9 guidance:
 **Configure synthesize on a fresh brain:**
+
+### Dream cycle (v0.23): synthesize + patterns — steps 10
+
 ```bash
 gbrain config set dream.synthesize.session_corpus_dir /path/to/transcripts
 gbrain config set dream.synthesize.enabled true
@@ -174,7 +240,7 @@
 gbrain dream                                       # full 8-phase cycle
 ```
 
-**Invocation patterns:**
+> **Invocation patterns:**
 ```bash
 gbrain dream                                          # full cycle
 gbrain dream --phase synthesize                       # just synthesize
@@ -184,27 +250,35 @@
 gbrain dream --json                                   # CycleReport JSON
 ```
 
-**Auto-commit deferred to v1.1:** v1 writes files to `brain_dir` but does NOT
-`git add` / `commit` / `push`. Either commit yourself or let `gbrain autopilot`
-handle it.
-Parses `- **YYYY-MM-DD** | Source — Summary` and `### YYYY-MM-DD — Title` formats.
+
+### Dream cycle (v0.23): synthesize + patterns — steps 11
+
 Note: extracted entries improve structured queries (`gbrain timeline`), not vector search.
 
-### Autopilot check
-Verify autopilot is running:
+### Autopilot check (( role: reference ))
+Autopilot runs sync, extract, and embed in a continuous loop with adaptive scheduling.
+
+### Autopilot check — steps
+
+> Verify autopilot is running:
 ```bash
 gbrain autopilot --status
 ```
-If not running, install it:
+> If not running, install it:
 ```bash
 gbrain autopilot --install --repo ~/brain
 ```
-Autopilot runs sync, extract, and embed in a continuous loop with adaptive scheduling.
+
+### Autopilot check — steps 2
+
 In v0.11.1+, autopilot dispatches each cycle as a single `autopilot-cycle`
 Minion job and supervises the worker child — one install step gives you
 sync + extract + embed + backlinks + durable job processing.
 
 ### Fix a half-migrated install
+
+### Fix a half-migrated install — steps
+
 A v0.11.0 install where the migration skill never fired leaves Minions
 partially set up: schema is applied, but `~/.gbrain/preferences.json`
 doesn't exist, autopilot runs inline, host manifests still reference
@@ -224,64 +298,86 @@
 
 Full troubleshooting guide: `docs/guides/minions-fix.md`.
 
-### Back-link enforcement
+### Back-link enforcement (( role: reference ))
 Check that the back-linking iron law is being followed:
 - For each recently updated page, check if entities mentioned in it have
   corresponding back-links FROM those entity pages
 - A mention without a back-link is a broken brain
 - Fix: add the missing back-link to the entity's Timeline or See Also section
-- Format: `- **YYYY-MM-DD** | Referenced in [page title](path) -- brief context`
-
-### Filing rule violations
+
+### Back-link enforcement — steps
+
+- Format: `- YYYY-MM-DD | Referenced in page title -- brief context`
+
+### Filing rule violations (( role: reference ))
+- Flag misfiled pages for review or re-filing
+
+
+### Filing rule violations — steps
+
 Check for common misfiling patterns (see `skills/_brain-filing-rules.md`):
 - Content with clear primary subjects filed in `sources/` instead of the
   appropriate directory (people/, companies/, concepts/, etc.)
 - Use gbrain search to find pages in `sources/` that reference specific
   people, companies, or concepts -- these may be misfiled
-- Flag misfiled pages for review or re-filing
-
-### Citation audit
-Spot-check pages for missing `[Source: ...]` citations:
+### Citation audit (( role: reference ))
 - Read 5-10 recently updated pages
 - Check that compiled truth (above the line) has inline citations
 - Check that timeline entries have source attribution
 - Flag pages where facts appear without provenance
 
-### Tag consistency
+
+### Citation audit — steps
+
+Spot-check pages for missing `[Source: ...]` citations:
+### Tag consistency (( role: reference ))
 Inconsistent tagging (e.g., "vc" vs "venture-capital", "ai" vs "artificial-intelligence").
 - Standardize to the most common variant using gbrain tag operations
 
-### Graph population (v0.10.3+)
+### Graph population (v0.10.3+) (( role: reference ))
 
 The `links` and `timeline_entries` tables are the structured graph layer.
-Populate them periodically or after major imports:
+- `gbrain stats` — verify `link_count > 0` and `timeline_entry_count > 0` after extraction.
+- `gbrain health` — review `link_coverage` and `timeline_coverage` percentages
+  on entity pages (person/company). Below 50% means more extraction is needed.
+
+`attended`, `works_at`, `invested_in`, `founded`, `advises`, `mentions`, `source`.
+
+Going forward, every `gbrain put` call auto-creates and reconciles links via the
+auto-link post-hook (default on; disable: `gbrain config set auto_link false`).
+So link-extract is mostly a one-time backfill. timeline-extract should be re-run
+after bulk imports or content edits that add new dated entries.
+
+
+### Graph population (v0.10.3+) — steps
+
+use judgment to follow the Graph population (v0.10.3+) — steps guidance:
+> Populate them periodically or after major imports:
 
 - `gbrain extract links --source db` — backfill structured links by walking pages
   from the engine. Reads `[Name](people/slug)` / `[Name](companies/slug)` references
   and infers relationship types (`attended`, `works_at`, `invested_in`, `founded`,
   `advises`, `mentions`, `source`). Idempotent. Use `--source fs --dir <brain>`
   if you have a markdown checkout to walk instead.
+
+### Graph population (v0.10.3+) — steps 2
+
 - `gbrain extract timeline --source db` — backfill structured timeline entries.
-  Parses `- **YYYY-MM-DD** | summary` lines from page content. Idempotent (DB
+  Parses `- YYYY-MM-DD | summary` lines from page content. Idempotent (DB
   UNIQUE constraint).
 - `gbrain extract all --source db` — both in one run.
 - `gbrain graph-query <slug> --depth 2` — verify connectivity (use any well-known
   entity slug as a probe).
-- `gbrain stats` — verify `link_count > 0` and `timeline_entry_count > 0` after extraction.
-- `gbrain health` — review `link_coverage` and `timeline_coverage` percentages
-  on entity pages (person/company). Below 50% means more extraction is needed.
+
+### Graph population (v0.10.3+) — steps 3
 
 Available link types (use with `gbrain graph-query --type`):
-`attended`, `works_at`, `invested_in`, `founded`, `advises`, `mentions`, `source`.
-
-Going forward, every `gbrain put` call auto-creates and reconciles links via the
-auto-link post-hook (default on; disable: `gbrain config set auto_link false`).
-So link-extract is mostly a one-time backfill. timeline-extract should be re-run
-after bulk imports or content edits that add new dated entries.
-
-### Embedding freshness
+### Embedding freshness (( role: reference ))
 Chunks without embeddings, or chunks embedded with an old model.
-- For large embedding refreshes (>1000 chunks), use nohup:
+
+### Embedding freshness — steps
+
+> - For large embedding refreshes (>1000 chunks), use nohup:
   `nohup gbrain embed refresh > /tmp/gbrain-embed.log 2>&1 &`
 - Then check progress: `tail -1 /tmp/gbrain-embed.log`
 
@@ -290,47 +386,65 @@
 All tables should show RLS enabled. If not, run `gbrain init` again.
 
 ### Schema health
+
+### Schema health — steps
+
 Check that the schema version is up to date. `gbrain doctor --json` reports
 the current version vs expected. If behind, `gbrain init` runs migrations
 automatically.
 
-### File storage health
-Check the integrity of stored files and redirect pointers:
+### File storage health (( role: reference ))
+- Check for large binary files (>= 100 MB) still in git that should be in cloud storage
+
+### File storage health — steps
+
+> Check the integrity of stored files and redirect pointers:
 - Run `gbrain files verify` to check all DB records have valid data
 - Run `gbrain files status` to see migration state (local, mirrored, redirected)
 - Check for orphan `.redirect.yaml` pointers that reference missing storage files
-- Check for large binary files (>= 100 MB) still in git that should be in cloud storage
+
+### File storage health — steps 2
+
 - If storage backend is configured: verify redirect pointers resolve (download test)
 
 ### Open threads
 Timeline items older than 30 days with unresolved action items.
 - Flag for review
 
-## Benchmark Testing
-
-Periodically verify search quality hasn't regressed. Run a battery of test
-queries across difficulty tiers:
-
-- **Tier 1 (entity lookup):** known names -- should always resolve
+## Benchmark Testing (( role: reference ))
+
 - **Tier 2 (topic recall):** concepts, topics -- keyword search should handle
 - **Tier 3 (semantic):** queries with no exact keyword match -- needs embeddings
 - **Tier 4 (cross-domain):** relational/connection queries -- only semantic handles
 
 Compare results from `gbrain search` (keyword) vs `gbrain query` (hybrid).
-Quality matters more than speed (2.5s right > 200ms wrong).
-
 When to run benchmarks:
 - After major brain imports or re-imports
 - After gbrain version upgrades
 - After embedding regeneration
 - Monthly to track quality drift
 
-## Heartbeat Integration
+
+### Benchmark Testing — steps
+
+> Periodically verify search quality hasn't regressed. Run a battery of test
+> queries across difficulty tiers:
+
+- Tier 1 (entity lookup): known names -- should always resolve
+
+### Benchmark Testing — steps 2
+
+Quality matters more than speed (2.5s right > 200ms wrong).
+
+## Heartbeat Integration (( role: reference ))
 
 For production agents running on a schedule, integrate gbrain health checks into
 your operational heartbeat.
 
 ### On every heartbeat (hourly or per-session)
+
+
+### On every heartbeat (hourly or per-session) — steps
 
 Run `gbrain doctor --json` and check for degradation. Report any failing checks
 to the user. Key signals: connection health, schema version, RLS status, embedding
@@ -338,6 +452,9 @@
 
 ### Weekly maintenance
 
+
+### Weekly maintenance — steps
+
 Run `gbrain embed --stale` to refresh embeddings for pages that have changed since
 their last embedding. For large brains (>5000 pages), run this with nohup:
 ```bash
@@ -346,37 +463,47 @@
 
 ### Daily verification
 
+
+### Daily verification — steps
+
 Verify sync is running: check `gbrain stats` and confirm `last_sync` is within
 the last 24 hours. If sync has stopped, the brain is drifting from the repo.
 
-### Stale compiled truth detection
+### Stale compiled truth detection (( role: reference ))
 
 Flag pages where compiled truth is >30 days old but the timeline has recent entries.
 This means new evidence exists that hasn't been synthesized. These pages need a
 compiled truth rewrite (see the maintain workflow above).
 
-## Report Storage
-
-After maintenance runs, save a report:
-- Health check results (before/after scores for each dimension)
+## Report Storage (( role: reference ))
+
 - Back-link violations found and fixed
 - Filing rule violations found
 - Citation gaps flagged
 - Benchmark results (if run)
+This creates an audit trail for brain health over time.
+
+
+### Report Storage — steps
+
+> After maintenance runs, save a report:
+- Health check results (before/after scores for each dimension)
+
+### Report Storage — steps 2
+
 - Outstanding issues requiring user attention
 
-This creates an audit trail for brain health over time.
-
-## Quality Rules
-
-- Never delete pages without confirmation
+## Quality Rules (( role: reference ))
+
 - Log all changes via timeline entries
 - Check gbrain health before and after to show improvement
 
-## Anti-Patterns
-
-- Fixing pages without reading them first -- you must understand context before editing
-- Silently skipping dimensions -- every dimension must be checked and reported, even if clean
+
+### Quality Rules — steps (( role: reference ))
+
+- Never delete pages without confirmation
+## Anti-Patterns (( role: reference ))
+
 - Deleting orphan pages without checking if they should be linked instead
 - Running embedding refresh during peak usage hours
 - Batch-fixing back-links without verifying the relationship is real
@@ -384,6 +511,15 @@
 - Rewriting compiled truth without reading the full timeline first
 - Removing tags without checking if other pages use the same tag consistently
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+use judgment to follow the Anti-Patterns — steps guidance:
+- Fixing pages without reading them first -- you must understand context before editing
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+- Silently skipping dimensions -- every dimension must be checked and reported, even if clean
 ## Output Format
 
 The maintenance report follows this structure:
```
