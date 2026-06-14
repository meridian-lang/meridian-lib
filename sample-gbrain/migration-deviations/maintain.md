# Deviation: maintain.meri

- Original: `maintain/SKILL.md`
- Ported: `maintain.meri`
- Tier: 2 (light edits)
- Similarity: 51%
- Lines: 431 -> 454 (+227 / -204)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 21/33 inert (64% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=19, template=1, tools-metadata=1
- Judgment: 5 blocks, 54 lines

### Inert section details
- L58 `Manual path`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L63 `Dimension reference`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L93 `Dream cycle (v0.23): synthesize + patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L206 `Back-link enforcement`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L220 `Filing rule violations`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L228 `Citation audit`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L235 `Tag consistency`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L239 `Graph population (v0.10.3+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L274 `Security (RLS verification)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L278 `Schema health`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L283 `File storage health`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L291 `Open threads`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L295 `Benchmark Testing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L314 `Heartbeat Integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L319 `On every heartbeat (hourly or per-session)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L333 `Daily verification`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L338 `Stale compiled truth detection`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L344 `Report Storage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L356 `Quality Rules`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L374 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L407 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/maintain/SKILL.md
+++ skills/maintain.meri
@@ -37,92 +37,105 @@
 
 # Maintain Skill
 
-Periodic brain health checks and cleanup.
-
-## Contract
-
-This skill guarantees:
-- All health dimensions are checked (stale, orphan, dead links, cross-refs, backlinks, citations, filing, tags)
-- Each issue found has a specific fix action
-- Back-link iron law is enforced
-- Citation format is validated against the standard
-- Results are reported with counts per dimension
+> Periodic brain health checks and cleanup.
+
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] All health dimensions are checked (stale, orphan, dead links, cross-refs, backlinks, citations, filing, tags)
+- [ ] Each issue found has a specific fix action
+- [ ] Back-link iron law is enforced
+- [ ] Citation format is validated against the standard
+- [ ] Results are reported with counts per dimension
 
 ## Phases
 
-### Autonomous path (v0.36.4.0) — when you want to reach a target score
-
-If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
-one-command loop over walking each dimension by hand:
-
-```bash
-gbrain doctor --remediation-plan --json              # preview what would run
-gbrain doctor --remediate --yes --target-score 90 --max-usd 5
-```
-
-`--remediation-plan` prints a dependency-ordered list (sync before extract,
-embed after consolidate, etc.) with per-step `est_seconds` and `est_usd_cost`.
-`--remediate` walks the plan, submitting each step as a Minion job, re-checking
-score between every step. `--max-usd N` is a hard cost cap — submission refuses
-when the plan would exceed the cap (prevents synthesize loops from burning
-Anthropic credits unattended).
-
-When the target score is unreachable for the brain (empty brain with no entity
-pages → `graph_coverage` caps at 70; unconfigured embedding key → caps at 60),
-the command bails with a list of what's missing rather than looping.
-
-Use the per-dimension walk below (Phase 2 onward) when:
-- The user explicitly asks for a dimension-by-dimension audit
-- You're investigating why score is stuck below `--remediate`'s ceiling
-- A specific dimension needs manual judgment that the auto path skips
-
-### Manual path
-
+### Page-health scan
+
+> Surface pages that need attention so the audit never reports a brain as
+> healthy while problems sit in it. Each dimension is a checkable adjective
+> (`unwritten`/`orphan`/`stale`) defined in `brain.merconfig`.
+
+bind pages = invoke list pages with filter = "all".
+if any pages are unwritten,
+  emit maintain.unwritten_pages with action = "review".
+if any pages are orphan,
+  emit maintain.orphan_pages with action = "link".
+if any pages are stale,
+  emit maintain.stale_pages with action = "rewrite".
+
+### Autonomous path (v0.36.4.0) — when you want to reach a target score (( role: procedure ))
+
+use judgment to follow the Autonomous path (v0.36.4.0) — when you want to reach a target score guidance:
+  If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
+  one-command loop over walking each dimension by hand:
+  
+  ```bash
+  gbrain doctor --remediation-plan --json              # preview what would run
+  gbrain doctor --remediate --yes --target-score 90 --max-usd 5
+  ```
+  
+  `--remediation-plan` prints a dependency-ordered list (sync before extract,
+  embed after consolidate, etc.) with per-step `est_seconds` and `est_usd_cost`.
+  `--remediate` walks the plan, submitting each step as a Minion job, re-checking
+  score between every step. `--max-usd N` is a hard cost cap — submission refuses
+  when the plan would exceed the cap (prevents synthesize loops from burning
+  Anthropic credits unattended).
+  
+  When the target score is unreachable for the brain (empty brain with no entity
+  pages → `graph_coverage` caps at 70; unconfigured embedding key → caps at 60),
+  the command bails with a list of what's missing rather than looping.
+  
+  Use the per-dimension walk below (Phase 2 onward) when:
+  item: The user explicitly asks for a dimension-by-dimension audit
+  item: You're investigating why score is stuck below `--remediate`'s ceiling
+  item: A specific dimension needs manual judgment that the auto path skips
+### Manual path (( inert ))
+  
 1. **Run health check.** Check gbrain health to get the dashboard.
 2. **Check each dimension:**
-
-### Stale pages
-Pages where compiled_truth is older than the latest timeline entry. The assessment hasn't been updated to reflect recent evidence.
-- Check the health output for stale page count
-- For each stale page: read the page from gbrain, review timeline, determine if compiled_truth needs rewriting
-
-### Orphan pages
-Pages with zero inbound links. Nobody references them.
-- Review orphans: are they genuinely isolated or just missing links?
-- Add links in gbrain from related pages or flag for deletion
-
-### Dead links
-Links pointing to pages that don't exist.
-- Remove dead links in gbrain
-
-### Missing cross-references
-Pages that mention entity names but don't have formal links.
-- Read compiled_truth from gbrain, extract entity mentions, create links in gbrain
-
-### Link graph extraction
-If link_count is 0 or low relative to page_count, run batch extraction:
-```bash
-gbrain extract links --dir ~/brain
-```
-This scans all markdown files for entity references, See Also sections, and
-frontmatter fields, then creates typed links in the database.
-
-### Timeline extraction
-If timeline_entry_count is 0, extract structured timeline from markdown:
-```bash
-gbrain extract timeline --dir ~/brain
-```
-
-### Dream cycle (v0.23): synthesize + patterns
-
+  
+### Dimension reference (( inert ))
+  
+The page-level dimensions are now checkable adjectives driven by the
+`Page-health scan` above, not hand-walked prose:
+  
+  item: **Stale** — `compiled truth` is empty (`Definition: a page is stale …`); the
+  assessment hasn't been written to reflect recent evidence.
+  item: **Orphan** — zero inbound links (`Definition: a page is orphan …`); nobody
+  references the page.
+  item: **Dead links / missing cross-references** — handled by the executable
+  `Create missing cross-references` and `Repair missing back-links` sections,
+  which add a back-link only when the relation is actually absent.
+  
+### Create missing cross-references
+  
+let referenced be the entities mentioned by the input.
+for each entity in referenced:
+  if the input does not reference the entity, add a back-link from the input to the entity.
+  
+### Graph extraction
+  
+> Backfill the structured graph layer when it is empty. The counts come from
+> the brain health dashboard; each guard runs the matching extraction command.
+  
+Check brain health.
+if the health's edge count is 0,
+  `gbrain extract links --dir ~/brain`.
+if the health's timeline count is 0,
+  `gbrain extract timeline --dir ~/brain`.
+  
+### Dream cycle (v0.23): synthesize + patterns (( inert ))
+  
 `gbrain dream` runs the full 8-phase maintenance cycle:
-
+  
 ```
 lint -> backlinks -> sync -> synthesize -> extract -> patterns -> embed -> orphans
 ```
-
+  
 The two new phases consolidate yesterday's conversations into long-term memory:
-
+  
 **Synthesize phase:** reads transcripts from `dream.synthesize.session_corpus_dir`,
 runs a cheap Haiku verdict (cached in `dream_verdicts`) to filter routine
 ops sessions, then fans out one Sonnet subagent per worth-processing
@@ -131,41 +144,41 @@
 orchestrator collects the slugs from `subagent_tool_executions` (NOT
 `pages.updated_at` — that would pick up unrelated writes) and reverse-renders
 each new page from DB → markdown on disk.
-
+  
 **Patterns phase:** runs after `extract` (so the graph state is fresh).
 Reads recent reflections within `dream.patterns.lookback_days` (default 30),
 runs a single Sonnet pass to surface recurring themes, and writes pattern
 pages to `wiki/personal/patterns/<theme>` when ≥`dream.patterns.min_evidence`
 (default 3) reflections support a pattern.
-
+  
 **Quality bar (Iron Law for synthesis):**
 1. Quote the user verbatim. Do not paraphrase memorable phrasings.
 2. Cross-reference compulsively: every new page MUST have at least one wikilink.
 3. Slug discipline: lowercase alphanumeric and hyphens only. NO underscores, NO file extensions.
 4. Edited transcripts produce NEW slugs (content-hash suffix changes) — never silently overwrite.
-
+  
 **Trust boundary (`allowed_slug_prefixes`):** the synthesis subagent runs with an
 explicit allow-list of write paths sourced from `_brain-filing-rules.json`'s
 `dream_synthesize_paths.globs`. Even on prompt-injection success, the subagent
 cannot write outside that list. Trust comes from PROTECTED_JOB_NAMES — MCP
 cannot submit subagent jobs at all. Editing the JSON is the only way to add
 a new directory the synthesizer can write to.
-
+  
 **Idempotency + privacy:** transcripts are keyed by `(file_path, content_hash)`,
 so re-running on the same content is a no-op. `dream.synthesize.exclude_patterns`
 (default `["medical", "therapy"]`) filters out transcripts before any LLM call.
 Each entry is auto-wrapped as a word-boundary regex (e.g. `medical` matches
 "medical advice" but NOT "comedical"). Power users may pass full regex.
-
+  
 **Cooldown:** the cycle's spend cap. `dream.synthesize.cooldown_hours` (default
 12) means at most ~2 synthesize runs per day under autopilot. The completion
 timestamp is stored in `dream.synthesize.last_completion_ts` and is written
 ONLY on successful runs (not on skipped/failed). Explicit `--input` /
 `--date` / `--from` / `--to` invocations bypass cooldown.
-
+  
 **`--dry-run` semantics:** runs the cheap Haiku significance filter (caches
 verdicts) but skips the Sonnet synthesis pass. NOT zero LLM calls.
-
+  
 **Configure synthesize on a fresh brain:**
 ```bash
 gbrain config set dream.synthesize.session_corpus_dir /path/to/transcripts
@@ -173,7 +186,7 @@
 gbrain dream --phase synthesize --dry-run --json   # preview
 gbrain dream                                       # full 8-phase cycle
 ```
-
+  
 **Invocation patterns:**
 ```bash
 gbrain dream                                          # full cycle
@@ -183,130 +196,139 @@
 gbrain dream --from 2026-04-01 --to 2026-04-25        # backfill range
 gbrain dream --json                                   # CycleReport JSON
 ```
-
+  
 **Auto-commit deferred to v1.1:** v1 writes files to `brain_dir` but does NOT
 `git add` / `commit` / `push`. Either commit yourself or let `gbrain autopilot`
 handle it.
 Parses `- **YYYY-MM-DD** | Source — Summary` and `### YYYY-MM-DD — Title` formats.
 Note: extracted entries improve structured queries (`gbrain timeline`), not vector search.
-
-### Autopilot check
-Verify autopilot is running:
-```bash
-gbrain autopilot --status
-```
-If not running, install it:
-```bash
-gbrain autopilot --install --repo ~/brain
-```
-Autopilot runs sync, extract, and embed in a continuous loop with adaptive scheduling.
-In v0.11.1+, autopilot dispatches each cycle as a single `autopilot-cycle`
-Minion job and supervises the worker child — one install step gives you
-sync + extract + embed + backlinks + durable job processing.
-
-### Fix a half-migrated install
-A v0.11.0 install where the migration skill never fired leaves Minions
-partially set up: schema is applied, but `~/.gbrain/preferences.json`
-doesn't exist, autopilot runs inline, host manifests still reference
-`agentTurn`. Repair:
-
-```bash
-# Check migration status
-gbrain apply-migrations --list
-
-# Apply pending migrations (idempotent; safe on healthy installs)
-gbrain apply-migrations --yes
-
-# If host-specific handlers are flagged in ~/.gbrain/migrations/pending-host-work.jsonl:
-# walk them per skills/migrations/v0.11.0.md + docs/guides/plugin-handlers.md,
-# ship handler registrations in the host repo, then re-run apply-migrations.
-```
-
-Full troubleshooting guide: `docs/guides/minions-fix.md`.
-
-### Back-link enforcement
+  
+### Autopilot check (( role: procedure ))
+  
+use judgment to follow the Autopilot check guidance:
+  Verify autopilot is running:
+  ```bash
+  gbrain autopilot --status
+  ```
+  If not running, install it:
+  ```bash
+  gbrain autopilot --install --repo ~/brain
+  ```
+  Autopilot runs sync, extract, and embed in a continuous loop with adaptive scheduling.
+  In v0.11.1+, autopilot dispatches each cycle as a single `autopilot-cycle`
+  Minion job and supervises the worker child — one install step gives you
+  sync + extract + embed + backlinks + durable job processing.
+### Fix a half-migrated install (( role: procedure ))
+  
+use judgment to follow the Fix a half-migrated install guidance:
+  A v0.11.0 install where the migration skill never fired leaves Minions
+  partially set up: schema is applied, but `~/.gbrain/preferences.json`
+  doesn't exist, autopilot runs inline, host manifests still reference
+  `agentTurn`. Repair:
+  
+  ```bash
+  # Check migration status
+  gbrain apply-migrations --list
+  
+  # Apply pending migrations (idempotent; safe on healthy installs)
+  gbrain apply-migrations --yes
+  
+  # If host-specific handlers are flagged in ~/.gbrain/migrations/pending-host-work.jsonl:
+  # walk them per skills/migrations/v0.11.0.md + docs/guides/plugin-handlers.md,
+  # ship handler registrations in the host repo, then re-run apply-migrations.
+  ```
+  
+  Full troubleshooting guide: `docs/guides/minions-fix.md`.
+### Back-link enforcement (( inert ))
 Check that the back-linking iron law is being followed:
-- For each recently updated page, check if entities mentioned in it have
+  item: For each recently updated page, check if entities mentioned in it have
   corresponding back-links FROM those entity pages
-- A mention without a back-link is a broken brain
-- Fix: add the missing back-link to the entity's Timeline or See Also section
-- Format: `- **YYYY-MM-DD** | Referenced in [page title](path) -- brief context`
-
-### Filing rule violations
+  item: A mention without a back-link is a broken brain
+  item: Fix: add the missing back-link to the entity's Timeline or See Also section
+  item: Format: `- **YYYY-MM-DD** | Referenced in [page title](path) -- brief context`
+  
+### Repair missing back-links
+  
+let mentioned be the entities mentioned by the input.
+for each entity in mentioned:
+  if the entity does not link to the input, add a back-link from the entity to the input.
+  
+### Filing rule violations (( inert ))
 Check for common misfiling patterns (see `skills/_brain-filing-rules.md`):
-- Content with clear primary subjects filed in `sources/` instead of the
+  item: Content with clear primary subjects filed in `sources/` instead of the
   appropriate directory (people/, companies/, concepts/, etc.)
-- Use gbrain search to find pages in `sources/` that reference specific
+  item: Use gbrain search to find pages in `sources/` that reference specific
   people, companies, or concepts -- these may be misfiled
-- Flag misfiled pages for review or re-filing
-
-### Citation audit
+  item: Flag misfiled pages for review or re-filing
+  
+### Citation audit (( inert ))
 Spot-check pages for missing `[Source: ...]` citations:
-- Read 5-10 recently updated pages
-- Check that compiled truth (above the line) has inline citations
-- Check that timeline entries have source attribution
-- Flag pages where facts appear without provenance
-
-### Tag consistency
+  item: Read 5-10 recently updated pages
+  item: Check that compiled truth (above the line) has inline citations
+  item: Check that timeline entries have source attribution
+  item: Flag pages where facts appear without provenance
+  
+### Tag consistency (( inert ))
 Inconsistent tagging (e.g., "vc" vs "venture-capital", "ai" vs "artificial-intelligence").
-- Standardize to the most common variant using gbrain tag operations
-
-### Graph population (v0.10.3+)
-
+  item: Standardize to the most common variant using gbrain tag operations
+  
+### Graph population (v0.10.3+) (( inert ))
+  
 The `links` and `timeline_entries` tables are the structured graph layer.
 Populate them periodically or after major imports:
-
-- `gbrain extract links --source db` — backfill structured links by walking pages
+  
+  item: `gbrain extract links --source db` — backfill structured links by walking pages
   from the engine. Reads `[Name](people/slug)` / `[Name](companies/slug)` references
   and infers relationship types (`attended`, `works_at`, `invested_in`, `founded`,
   `advises`, `mentions`, `source`). Idempotent. Use `--source fs --dir <brain>`
   if you have a markdown checkout to walk instead.
-- `gbrain extract timeline --source db` — backfill structured timeline entries.
+  item: `gbrain extract timeline --source db` — backfill structured timeline entries.
   Parses `- **YYYY-MM-DD** | summary` lines from page content. Idempotent (DB
   UNIQUE constraint).
-- `gbrain extract all --source db` — both in one run.
-- `gbrain graph-query <slug> --depth 2` — verify connectivity (use any well-known
+  item: `gbrain extract all --source db` — both in one run.
+  item: `gbrain graph-query <slug> --depth 2` — verify connectivity (use any well-known
   entity slug as a probe).
-- `gbrain stats` — verify `link_count > 0` and `timeline_entry_count > 0` after extraction.
-- `gbrain health` — review `link_coverage` and `timeline_coverage` percentages
+  item: `gbrain stats` — verify `link_count > 0` and `timeline_entry_count > 0` after extraction.
+  item: `gbrain health` — review `link_coverage` and `timeline_coverage` percentages
   on entity pages (person/company). Below 50% means more extraction is needed.
-
+  
 Available link types (use with `gbrain graph-query --type`):
 `attended`, `works_at`, `invested_in`, `founded`, `advises`, `mentions`, `source`.
-
+  
 Going forward, every `gbrain put` call auto-creates and reconciles links via the
 auto-link post-hook (default on; disable: `gbrain config set auto_link false`).
 So link-extract is mostly a one-time backfill. timeline-extract should be re-run
 after bulk imports or content edits that add new dated entries.
-
-### Embedding freshness
-Chunks without embeddings, or chunks embedded with an old model.
-- For large embedding refreshes (>1000 chunks), use nohup:
-  `nohup gbrain embed refresh > /tmp/gbrain-embed.log 2>&1 &`
-- Then check progress: `tail -1 /tmp/gbrain-embed.log`
-
-### Security (RLS verification)
+  
+### Embedding freshness (( role: procedure ))
+  
+use judgment to follow the Embedding freshness guidance:
+  Chunks without embeddings, or chunks embedded with an old model.
+  item: For large embedding refreshes (>1000 chunks), use nohup:
+    `nohup gbrain embed refresh > /tmp/gbrain-embed.log 2>&1 &`
+  item: Then check progress: `tail -1 /tmp/gbrain-embed.log`
+### Security (RLS verification) (( inert ))
 Run `gbrain doctor --json` and check the RLS status.
 All tables should show RLS enabled. If not, run `gbrain init` again.
-
-### Schema health
+  
+### Schema health (( inert ))
 Check that the schema version is up to date. `gbrain doctor --json` reports
 the current version vs expected. If behind, `gbrain init` runs migrations
 automatically.
-
-### File storage health
+  
+### File storage health (( inert ))
 Check the integrity of stored files and redirect pointers:
-- Run `gbrain files verify` to check all DB records have valid data
-- Run `gbrain files status` to see migration state (local, mirrored, redirected)
-- Check for orphan `.redirect.yaml` pointers that reference missing storage files
-- Check for large binary files (>= 100 MB) still in git that should be in cloud storage
-- If storage backend is configured: verify redirect pointers resolve (download test)
-
-### Open threads
+  item: Run `gbrain files verify` to check all DB records have valid data
+  item: Run `gbrain files status` to see migration state (local, mirrored, redirected)
+  item: Check for orphan `.redirect.yaml` pointers that reference missing storage files
+  item: Check for large binary files (>= 100 MB) still in git that should be in cloud storage
+  item: If storage backend is configured: verify redirect pointers resolve (download test)
+  
+### Open threads (( inert ))
 Timeline items older than 30 days with unresolved action items.
-- Flag for review
-
-## Benchmark Testing
+  item: Flag for review
+
+## Benchmark Testing (( inert ))
 
 Periodically verify search quality hasn't regressed. Run a battery of test
 queries across difficulty tiers:
@@ -325,37 +347,37 @@
 - After embedding regeneration
 - Monthly to track quality drift
 
-## Heartbeat Integration
+## Heartbeat Integration (( inert ))
 
 For production agents running on a schedule, integrate gbrain health checks into
 your operational heartbeat.
 
-### On every heartbeat (hourly or per-session)
+### On every heartbeat (hourly or per-session) (( inert ))
 
 Run `gbrain doctor --json` and check for degradation. Report any failing checks
 to the user. Key signals: connection health, schema version, RLS status, embedding
 staleness.
 
-### Weekly maintenance
-
-Run `gbrain embed --stale` to refresh embeddings for pages that have changed since
-their last embedding. For large brains (>5000 pages), run this with nohup:
-```bash
-nohup gbrain embed --stale > /tmp/gbrain-embed.log 2>&1 &
-```
-
-### Daily verification
-
+### Weekly maintenance (( role: procedure ))
+
+use judgment to follow the Weekly maintenance guidance:
+  Run `gbrain embed --stale` to refresh embeddings for pages that have changed since
+  their last embedding. For large brains (>5000 pages), run this with nohup:
+  ```bash
+  nohup gbrain embed --stale > /tmp/gbrain-embed.log 2>&1 &
+  ```
+### Daily verification (( inert ))
+  
 Verify sync is running: check `gbrain stats` and confirm `last_sync` is within
 the last 24 hours. If sync has stopped, the brain is drifting from the repo.
-
-### Stale compiled truth detection
-
+  
+### Stale compiled truth detection (( inert ))
+  
 Flag pages where compiled truth is >30 days old but the timeline has recent entries.
 This means new evidence exists that hasn't been synthesized. These pages need a
 compiled truth rewrite (see the maintain workflow above).
 
-## Report Storage
+## Report Storage (( inert ))
 
 After maintenance runs, save a report:
 - Health check results (before/after scores for each dimension)
@@ -367,29 +389,30 @@
 
 This creates an audit trail for brain health over time.
 
-## Quality Rules
+## Quality Rules (( inert ))
 
 - Never delete pages without confirmation
 - Log all changes via timeline entries
 - Check gbrain health before and after to show improvement
 
-## Anti-Patterns
-
-- Fixing pages without reading them first -- you must understand context before editing
-- Silently skipping dimensions -- every dimension must be checked and reported, even if clean
-- Deleting orphan pages without checking if they should be linked instead
-- Running embedding refresh during peak usage hours
-- Batch-fixing back-links without verifying the relationship is real
-- Marking a dimension "clean" without actually querying it
-- Rewriting compiled truth without reading the full timeline first
-- Removing tags without checking if other pages use the same tag consistently
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Fixing pages without reading them first -- you must understand context before editing
+- [ ] Silently skipping dimensions -- every dimension must be checked and reported, even if clean
+- [ ] Deleting orphan pages without checking if they should be linked instead
+- [ ] Running embedding refresh during peak usage hours
+- [ ] Batch-fixing back-links without verifying the relationship is real
+- [ ] Marking a dimension "clean" without actually querying it
+- [ ] Rewriting compiled truth without reading the full timeline first
+- [ ] Removing tags without checking if other pages use the same tag consistently
 
 ## Output Format
 
 The maintenance report follows this structure:
 
 ```
-## Brain Health Report — YYYY-MM-DD
+## Brain Health Report — YYYY-MM-DD (( inert ))
 
 | Dimension           | Issues Found | Fixed | Remaining |
 |----------------------|-------------|-------|-----------|
@@ -407,13 +430,13 @@
 | File storage         | N           | N     | N         |
 | Open threads         | N           | N     | N         |
 
-### Details
+### Details (( inert ))
 [Per-dimension breakdown with specific pages and actions taken]
 
-### Benchmark Results (if run)
+### Benchmark Results (if run) (( inert ))
 [Tier 1-4 query results with pass/fail]
 
-### Outstanding Issues
+### Outstanding Issues (( inert ))
 [Items requiring user attention or confirmation]
 ```
 
```
