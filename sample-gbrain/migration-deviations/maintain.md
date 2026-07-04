# Deviation: maintain.meri

- Original: `maintain/SKILL.md`
- Ported: `maintain.meri`
- Tier: 2 (light edits)
- Similarity: 74%
- Lines: 431 -> 519 (+167 / -79)

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
- L70 `Orphan pages`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L75 `Dead links`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L79 `Missing cross-references`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L268 `Tag consistency`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L366 `Heartbeat Integration`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L399 `Stale compiled truth detection`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L439 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L472 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 18/29 (62% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=16, template=1, tools-metadata=1
- Judgment: 10 blocks, 0 lines

### Inert section details
- L19 `Autonomous path (v0.36.4.0) — when you want to reach a target score`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L54 `Manual path`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L62 `Stale pages`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L70 `Orphan pages`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L75 `Dead links`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L79 `Missing cross-references`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L83 `Link graph extraction`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L196 `Autopilot check`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L249 `Filing rule violations`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L268 `Tag consistency`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L272 `Graph population (v0.10.3+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L306 `Embedding freshness`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L327 `File storage health`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L366 `Heartbeat Integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L399 `Stale compiled truth detection`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L405 `Report Storage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L439 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L472 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/maintain/SKILL.md
+++ skills/maintain.meri
@@ -37,9 +37,10 @@
 
 # Maintain Skill
 
-Periodic brain health checks and cleanup.
-
-## Contract
+> Periodic brain health checks and cleanup.
+
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - All health dimensions are checked (stale, orphan, dead links, cross-refs, backlinks, citations, filing, tags)
@@ -49,16 +50,9 @@
 - Results are reported with counts per dimension
 
 ## Phases
-
-### Autonomous path (v0.36.4.0) — when you want to reach a target score
-
-If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
-one-command loop over walking each dimension by hand:
-
-```bash
-gbrain doctor --remediation-plan --json              # preview what would run
-gbrain doctor --remediate --yes --target-score 90 --max-usd 5
-```
+use judgment to follow the Phases guidance:
+
+### Autonomous path (v0.36.4.0) — when you want to reach a target score (( inert ))
 
 `--remediation-plan` prints a dependency-ordered list (sync before extract,
 embed after consolidate, etc.) with per-step `est_seconds` and `est_usd_cost`.
@@ -67,55 +61,83 @@
 when the plan would exceed the cap (prevents synthesize loops from burning
 Anthropic credits unattended).
 
+Use the per-dimension walk below (Phase 2 onward) when:
+- The user explicitly asks for a dimension-by-dimension audit
+- A specific dimension needs manual judgment that the auto path skips
+
+
+#### Autonomous path (v0.36.4.0) — when you want to reach a target score — steps
+
+> If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
+> one-command loop over walking each dimension by hand:
+
+```bash
+gbrain doctor --remediation-plan --json              # preview what would run
+gbrain doctor --remediate --yes --target-score 90 --max-usd 5
+```
+
+
+#### Autonomous path (v0.36.4.0) — when you want to reach a target score — steps 2
+
 When the target score is unreachable for the brain (empty brain with no entity
 pages → `graph_coverage` caps at 70; unconfigured embedding key → caps at 60),
 the command bails with a list of what's missing rather than looping.
 
-Use the per-dimension walk below (Phase 2 onward) when:
-- The user explicitly asks for a dimension-by-dimension audit
+
+#### Autonomous path (v0.36.4.0) — when you want to reach a target score — steps 3
+
 - You're investigating why score is stuck below `--remediate`'s ceiling
-- A specific dimension needs manual judgment that the auto path skips
-
-### Manual path
-
-1. **Run health check.** Check gbrain health to get the dashboard.
+### Manual path (( inert ))
+
 2. **Check each dimension:**
 
-### Stale pages
+
+#### Manual path — steps
+
+1. Check gbrain health to get the dashboard.
+### Stale pages (( inert ))
 Pages where compiled_truth is older than the latest timeline entry. The assessment hasn't been updated to reflect recent evidence.
+
+#### Stale pages — steps
+
 - Check the health output for stale page count
 - For each stale page: read the page from gbrain, review timeline, determine if compiled_truth needs rewriting
 
-### Orphan pages
+### Orphan pages (( inert ))
 Pages with zero inbound links. Nobody references them.
 - Review orphans: are they genuinely isolated or just missing links?
 - Add links in gbrain from related pages or flag for deletion
 
-### Dead links
+### Dead links (( inert ))
 Links pointing to pages that don't exist.
 - Remove dead links in gbrain
 
-### Missing cross-references
+### Missing cross-references (( inert ))
 Pages that mention entity names but don't have formal links.
 - Read compiled_truth from gbrain, extract entity mentions, create links in gbrain
 
-### Link graph extraction
-If link_count is 0 or low relative to page_count, run batch extraction:
-```bash
-gbrain extract links --dir ~/brain
-```
+### Link graph extraction (( inert ))
 This scans all markdown files for entity references, See Also sections, and
 frontmatter fields, then creates typed links in the database.
 
-### Timeline extraction
-If timeline_entry_count is 0, extract structured timeline from markdown:
+
+#### Link graph extraction — steps
+
+> If link_count is 0 or low relative to page_count, run batch extraction:
+```bash
+gbrain extract links --dir ~/brain
+```
+### Timeline extraction (( inert ))
+
+#### Timeline extraction — steps
+
+> If timeline_entry_count is 0, extract structured timeline from markdown:
 ```bash
 gbrain extract timeline --dir ~/brain
 ```
 
 ### Dream cycle (v0.23): synthesize + patterns
-
-`gbrain dream` runs the full 8-phase maintenance cycle:
+use judgment to follow the Dream cycle (v0.23): synthesize + patterns guidance:
 
 ```
 lint -> backlinks -> sync -> synthesize -> extract -> patterns -> embed -> orphans
@@ -140,7 +162,6 @@
 
 **Quality bar (Iron Law for synthesis):**
 1. Quote the user verbatim. Do not paraphrase memorable phrasings.
-2. Cross-reference compulsively: every new page MUST have at least one wikilink.
 3. Slug discipline: lowercase alphanumeric and hyphens only. NO underscores, NO file extensions.
 4. Edited transcripts produce NEW slugs (content-hash suffix changes) — never silently overwrite.
 
@@ -157,16 +178,35 @@
 Each entry is auto-wrapped as a word-boundary regex (e.g. `medical` matches
 "medical advice" but NOT "comedical"). Power users may pass full regex.
 
-**Cooldown:** the cycle's spend cap. `dream.synthesize.cooldown_hours` (default
 12) means at most ~2 synthesize runs per day under autopilot. The completion
 timestamp is stored in `dream.synthesize.last_completion_ts` and is written
 ONLY on successful runs (not on skipped/failed). Explicit `--input` /
 `--date` / `--from` / `--to` invocations bypass cooldown.
 
-**`--dry-run` semantics:** runs the cheap Haiku significance filter (caches
+**Auto-commit deferred to v1.1:** v1 writes files to `brain_dir` but does NOT
+`git add` / `commit` / `push`. Either commit yourself or let `gbrain autopilot`
+handle it.
+Parses `- **YYYY-MM-DD** | Source — Summary` and `### YYYY-MM-DD — Title` formats.
+
+#### Dream cycle (v0.23): synthesize + patterns — steps
+
+`gbrain dream` runs the full 8-phase maintenance cycle:
+
+
+#### Dream cycle (v0.23): synthesize + patterns — steps 2
+
+2. Cross-reference compulsively: every new page MUST have at least one wikilink.
+
+#### Dream cycle (v0.23): synthesize + patterns — steps 3
+
+Cooldown: the cycle's spend cap. `dream.synthesize.cooldown_hours` (default
+
+#### Dream cycle (v0.23): synthesize + patterns — steps 4
+
+`--dry-run` semantics: runs the cheap Haiku significance filter (caches
 verdicts) but skips the Sonnet synthesis pass. NOT zero LLM calls.
 
-**Configure synthesize on a fresh brain:**
+> **Configure synthesize on a fresh brain:**
 ```bash
 gbrain config set dream.synthesize.session_corpus_dir /path/to/transcripts
 gbrain config set dream.synthesize.enabled true
@@ -174,7 +214,7 @@
 gbrain dream                                       # full 8-phase cycle
 ```
 
-**Invocation patterns:**
+> **Invocation patterns:**
 ```bash
 gbrain dream                                          # full cycle
 gbrain dream --phase synthesize                       # just synthesize
@@ -184,32 +224,41 @@
 gbrain dream --json                                   # CycleReport JSON
 ```
 
-**Auto-commit deferred to v1.1:** v1 writes files to `brain_dir` but does NOT
-`git add` / `commit` / `push`. Either commit yourself or let `gbrain autopilot`
-handle it.
-Parses `- **YYYY-MM-DD** | Source — Summary` and `### YYYY-MM-DD — Title` formats.
+
+#### Dream cycle (v0.23): synthesize + patterns — steps 5
+
 Note: extracted entries improve structured queries (`gbrain timeline`), not vector search.
 
-### Autopilot check
-Verify autopilot is running:
+### Autopilot check (( inert ))
+Autopilot runs sync, extract, and embed in a continuous loop with adaptive scheduling.
+
+#### Autopilot check — steps
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
+#### Autopilot check — steps 2
+
 In v0.11.1+, autopilot dispatches each cycle as a single `autopilot-cycle`
 Minion job and supervises the worker child — one install step gives you
 sync + extract + embed + backlinks + durable job processing.
 
 ### Fix a half-migrated install
+use judgment to follow the Fix a half-migrated install guidance:
 A v0.11.0 install where the migration skill never fired leaves Minions
 partially set up: schema is applied, but `~/.gbrain/preferences.json`
 doesn't exist, autopilot runs inline, host manifests still reference
 `agentTurn`. Repair:
 
+
+#### Fix a half-migrated install — steps
+
 ```bash
 # Check migration status
 gbrain apply-migrations --list
@@ -225,6 +274,7 @@
 Full troubleshooting guide: `docs/guides/minions-fix.md`.
 
 ### Back-link enforcement
+use judgment to follow the Back-link enforcement guidance:
 Check that the back-linking iron law is being followed:
 - For each recently updated page, check if entities mentioned in it have
   corresponding back-links FROM those entity pages
@@ -232,26 +282,30 @@
 - Fix: add the missing back-link to the entity's Timeline or See Also section
 - Format: `- **YYYY-MM-DD** | Referenced in [page title](path) -- brief context`
 
-### Filing rule violations
+### Filing rule violations (( inert ))
+- Flag misfiled pages for review or re-filing
+
+
+#### Filing rule violations — steps
+
 Check for common misfiling patterns (see `skills/_brain-filing-rules.md`):
 - Content with clear primary subjects filed in `sources/` instead of the
   appropriate directory (people/, companies/, concepts/, etc.)
 - Use gbrain search to find pages in `sources/` that reference specific
   people, companies, or concepts -- these may be misfiled
-- Flag misfiled pages for review or re-filing
-
 ### Citation audit
+use judgment to follow the Citation audit guidance:
 Spot-check pages for missing `[Source: ...]` citations:
 - Read 5-10 recently updated pages
 - Check that compiled truth (above the line) has inline citations
 - Check that timeline entries have source attribution
 - Flag pages where facts appear without provenance
 
-### Tag consistency
+### Tag consistency (( inert ))
 Inconsistent tagging (e.g., "vc" vs "venture-capital", "ai" vs "artificial-intelligence").
 - Standardize to the most common variant using gbrain tag operations
 
-### Graph population (v0.10.3+)
+### Graph population (v0.10.3+) (( inert ))
 
 The `links` and `timeline_entries` tables are the structured graph layer.
 Populate them periodically or after major imports:
@@ -261,27 +315,36 @@
   and infers relationship types (`attended`, `works_at`, `invested_in`, `founded`,
   `advises`, `mentions`, `source`). Idempotent. Use `--source fs --dir <brain>`
   if you have a markdown checkout to walk instead.
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
+#### Graph population (v0.10.3+) — steps
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
+#### Graph population (v0.10.3+) — steps 2
 
 Available link types (use with `gbrain graph-query --type`):
-`attended`, `works_at`, `invested_in`, `founded`, `advises`, `mentions`, `source`.
-
-Going forward, every `gbrain put` call auto-creates and reconciles links via the
-auto-link post-hook (default on; disable: `gbrain config set auto_link false`).
-So link-extract is mostly a one-time backfill. timeline-extract should be re-run
-after bulk imports or content edits that add new dated entries.
-
-### Embedding freshness
+### Embedding freshness (( inert ))
 Chunks without embeddings, or chunks embedded with an old model.
-- For large embedding refreshes (>1000 chunks), use nohup:
+
+#### Embedding freshness — steps
+
+> - For large embedding refreshes (>1000 chunks), use nohup:
   `nohup gbrain embed refresh > /tmp/gbrain-embed.log 2>&1 &`
 - Then check progress: `tail -1 /tmp/gbrain-embed.log`
 
@@ -289,24 +352,35 @@
 Run `gbrain doctor --json` and check the RLS status.
 All tables should show RLS enabled. If not, run `gbrain init` again.
 
-### Schema health
+### Schema health (( inert ))
+
+#### Schema health — steps
+
 Check that the schema version is up to date. `gbrain doctor --json` reports
 the current version vs expected. If behind, `gbrain init` runs migrations
 automatically.
 
-### File storage health
-Check the integrity of stored files and redirect pointers:
+### File storage health (( inert ))
+- Check for large binary files (>= 100 MB) still in git that should be in cloud storage
+
+#### File storage health — steps
+
+> Check the integrity of stored files and redirect pointers:
 - Run `gbrain files verify` to check all DB records have valid data
 - Run `gbrain files status` to see migration state (local, mirrored, redirected)
 - Check for orphan `.redirect.yaml` pointers that reference missing storage files
-- Check for large binary files (>= 100 MB) still in git that should be in cloud storage
+
+#### File storage health — steps 2
+
 - If storage backend is configured: verify redirect pointers resolve (download test)
 
 ### Open threads
+use judgment to follow the Open threads guidance:
 Timeline items older than 30 days with unresolved action items.
 - Flag for review
 
 ## Benchmark Testing
+use judgment to follow the Benchmark Testing guidance:
 
 Periodically verify search quality hasn't regressed. Run a battery of test
 queries across difficulty tiers:
@@ -325,18 +399,24 @@
 - After embedding regeneration
 - Monthly to track quality drift
 
-## Heartbeat Integration
+## Heartbeat Integration (( inert ))
 
 For production agents running on a schedule, integrate gbrain health checks into
 your operational heartbeat.
 
-### On every heartbeat (hourly or per-session)
+### On every heartbeat (hourly or per-session) (( inert ))
+
+
+#### On every heartbeat (hourly or per-session) — steps
 
 Run `gbrain doctor --json` and check for degradation. Report any failing checks
 to the user. Key signals: connection health, schema version, RLS status, embedding
 staleness.
 
-### Weekly maintenance
+### Weekly maintenance (( inert ))
+
+
+#### Weekly maintenance — steps
 
 Run `gbrain embed --stale` to refresh embeddings for pages that have changed since
 their last embedding. For large brains (>5000 pages), run this with nohup:
@@ -344,21 +424,22 @@
 nohup gbrain embed --stale > /tmp/gbrain-embed.log 2>&1 &
 ```
 
-### Daily verification
+### Daily verification (( inert ))
+
+
+#### Daily verification — steps
 
 Verify sync is running: check `gbrain stats` and confirm `last_sync` is within
 the last 24 hours. If sync has stopped, the brain is drifting from the repo.
 
-### Stale compiled truth detection
+### Stale compiled truth detection (( inert ))
 
 Flag pages where compiled truth is >30 days old but the timeline has recent entries.
 This means new evidence exists that hasn't been synthesized. These pages need a
 compiled truth rewrite (see the maintain workflow above).
 
-## Report Storage
-
-After maintenance runs, save a report:
-- Health check results (before/after scores for each dimension)
+## Report Storage (( inert ))
+
 - Back-link violations found and fixed
 - Filing rule violations found
 - Citation gaps flagged
@@ -367,13 +448,20 @@
 
 This creates an audit trail for brain health over time.
 
-## Quality Rules
+
+### Report Storage — steps
+
+> After maintenance runs, save a report:
+- Health check results (before/after scores for each dimension)
+## Quality Rules (( role: procedure ))
+use judgment to follow the Quality Rules guidance:
 
 - Never delete pages without confirmation
 - Log all changes via timeline entries
 - Check gbrain health before and after to show improvement
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Fixing pages without reading them first -- you must understand context before editing
 - Silently skipping dimensions -- every dimension must be checked and reported, even if clean
```
