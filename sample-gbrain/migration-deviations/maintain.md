# Deviation: maintain.meri

- Original: `maintain/SKILL.md`
- Ported: `maintain.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 431 -> 431 (+40 / -40)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 34/34 inert (100% inert ratio)
- Operational inert: 10
- Unclassified inert: 0
- Inert categories: normative-contract=2, operational-content=7, operational-procedure=1, reference-documentation=22, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L15 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L17 `Autonomous path (v0.36.4.0) — when you want to reach a target score`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L43 `Manual path`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L48 `Stale pages`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L53 `Orphan pages`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L58 `Dead links`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L62 `Missing cross-references`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L66 `Link graph extraction`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L74 `Timeline extraction`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L80 `Dream cycle (v0.23): synthesize + patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L157 `Autopilot check`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L171 `Fix a half-migrated install`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L191 `Back-link enforcement`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L199 `Filing rule violations`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L207 `Citation audit`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L214 `Tag consistency`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L218 `Graph population (v0.10.3+)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L246 `Embedding freshness`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L252 `Security (RLS verification)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L256 `Schema health`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L261 `File storage health`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L269 `Open threads`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L273 `Benchmark Testing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L292 `Heartbeat Integration`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L297 `On every heartbeat (hourly or per-session)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L303 `Weekly maintenance`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L311 `Daily verification`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L316 `Stale compiled truth detection`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L322 `Report Storage`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L334 `Quality Rules`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L340 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L351 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L384 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/maintain/SKILL.md
+++ skills/maintain.meri
@@ -37,9 +37,9 @@
 
 # Maintain Skill
 
-Periodic brain health checks and cleanup.
-
-## Contract
+> Periodic brain health checks and cleanup.
+
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - All health dimensions are checked (stale, orphan, dead links, cross-refs, backlinks, citations, filing, tags)
@@ -48,9 +48,9 @@
 - Citation format is validated against the standard
 - Results are reported with counts per dimension
 
-## Phases
-
-### Autonomous path (v0.36.4.0) — when you want to reach a target score
+## Phases (( inert, role: procedure ))
+
+### Autonomous path (v0.36.4.0) — when you want to reach a target score (( inert ))
 
 If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
 one-command loop over walking each dimension by hand:
@@ -76,30 +76,30 @@
 - You're investigating why score is stuck below `--remediate`'s ceiling
 - A specific dimension needs manual judgment that the auto path skips
 
-### Manual path
+### Manual path (( inert ))
 
 1. **Run health check.** Check gbrain health to get the dashboard.
 2. **Check each dimension:**
 
-### Stale pages
+### Stale pages (( inert ))
 Pages where compiled_truth is older than the latest timeline entry. The assessment hasn't been updated to reflect recent evidence.
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
+### Link graph extraction (( inert ))
 If link_count is 0 or low relative to page_count, run batch extraction:
 ```bash
 gbrain extract links --dir ~/brain
@@ -107,13 +107,13 @@
 This scans all markdown files for entity references, See Also sections, and
 frontmatter fields, then creates typed links in the database.
 
-### Timeline extraction
+### Timeline extraction (( inert ))
 If timeline_entry_count is 0, extract structured timeline from markdown:
 ```bash
 gbrain extract timeline --dir ~/brain
 ```
 
-### Dream cycle (v0.23): synthesize + patterns
+### Dream cycle (v0.23): synthesize + patterns (( inert ))
 
 `gbrain dream` runs the full 8-phase maintenance cycle:
 
@@ -190,7 +190,7 @@
 Parses `- **YYYY-MM-DD** | Source — Summary` and `### YYYY-MM-DD — Title` formats.
 Note: extracted entries improve structured queries (`gbrain timeline`), not vector search.
 
-### Autopilot check
+### Autopilot check (( inert ))
 Verify autopilot is running:
 ```bash
 gbrain autopilot --status
@@ -204,7 +204,7 @@
 Minion job and supervises the worker child — one install step gives you
 sync + extract + embed + backlinks + durable job processing.
 
-### Fix a half-migrated install
+### Fix a half-migrated install (( inert ))
 A v0.11.0 install where the migration skill never fired leaves Minions
 partially set up: schema is applied, but `~/.gbrain/preferences.json`
 doesn't exist, autopilot runs inline, host manifests still reference
@@ -224,7 +224,7 @@
 
 Full troubleshooting guide: `docs/guides/minions-fix.md`.
 
-### Back-link enforcement
+### Back-link enforcement (( inert ))
 Check that the back-linking iron law is being followed:
 - For each recently updated page, check if entities mentioned in it have
   corresponding back-links FROM those entity pages
@@ -232,7 +232,7 @@
 - Fix: add the missing back-link to the entity's Timeline or See Also section
 - Format: `- **YYYY-MM-DD** | Referenced in [page title](path) -- brief context`
 
-### Filing rule violations
+### Filing rule violations (( inert ))
 Check for common misfiling patterns (see `skills/_brain-filing-rules.md`):
 - Content with clear primary subjects filed in `sources/` instead of the
   appropriate directory (people/, companies/, concepts/, etc.)
@@ -240,18 +240,18 @@
   people, companies, or concepts -- these may be misfiled
 - Flag misfiled pages for review or re-filing
 
-### Citation audit
+### Citation audit (( inert ))
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
@@ -279,22 +279,22 @@
 So link-extract is mostly a one-time backfill. timeline-extract should be re-run
 after bulk imports or content edits that add new dated entries.
 
-### Embedding freshness
+### Embedding freshness (( inert ))
 Chunks without embeddings, or chunks embedded with an old model.
 - For large embedding refreshes (>1000 chunks), use nohup:
   `nohup gbrain embed refresh > /tmp/gbrain-embed.log 2>&1 &`
 - Then check progress: `tail -1 /tmp/gbrain-embed.log`
 
-### Security (RLS verification)
+### Security (RLS verification) (( inert ))
 Run `gbrain doctor --json` and check the RLS status.
 All tables should show RLS enabled. If not, run `gbrain init` again.
 
-### Schema health
+### Schema health (( inert ))
 Check that the schema version is up to date. `gbrain doctor --json` reports
 the current version vs expected. If behind, `gbrain init` runs migrations
 automatically.
 
-### File storage health
+### File storage health (( inert ))
 Check the integrity of stored files and redirect pointers:
 - Run `gbrain files verify` to check all DB records have valid data
 - Run `gbrain files status` to see migration state (local, mirrored, redirected)
@@ -302,11 +302,11 @@
 - Check for large binary files (>= 100 MB) still in git that should be in cloud storage
 - If storage backend is configured: verify redirect pointers resolve (download test)
 
-### Open threads
+### Open threads (( inert ))
 Timeline items older than 30 days with unresolved action items.
 - Flag for review
 
-## Benchmark Testing
+## Benchmark Testing (( inert ))
 
 Periodically verify search quality hasn't regressed. Run a battery of test
 queries across difficulty tiers:
@@ -325,18 +325,18 @@
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
+### Weekly maintenance (( inert ))
 
 Run `gbrain embed --stale` to refresh embeddings for pages that have changed since
 their last embedding. For large brains (>5000 pages), run this with nohup:
@@ -344,18 +344,18 @@
 nohup gbrain embed --stale > /tmp/gbrain-embed.log 2>&1 &
 ```
 
-### Daily verification
+### Daily verification (( inert ))
 
 Verify sync is running: check `gbrain stats` and confirm `last_sync` is within
 the last 24 hours. If sync has stopped, the brain is drifting from the repo.
 
-### Stale compiled truth detection
+### Stale compiled truth detection (( inert ))
 
 Flag pages where compiled truth is >30 days old but the timeline has recent entries.
 This means new evidence exists that hasn't been synthesized. These pages need a
 compiled truth rewrite (see the maintain workflow above).
 
-## Report Storage
+## Report Storage (( inert ))
 
 After maintenance runs, save a report:
 - Health check results (before/after scores for each dimension)
@@ -367,13 +367,13 @@
 
 This creates an audit trail for brain health over time.
 
-## Quality Rules
+## Quality Rules (( inert, role: invariants ))
 
 - Never delete pages without confirmation
 - Log all changes via timeline entries
 - Check gbrain health before and after to show improvement
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Fixing pages without reading them first -- you must understand context before editing
 - Silently skipping dimensions -- every dimension must be checked and reported, even if clean
@@ -384,12 +384,12 @@
 - Rewriting compiled truth without reading the full timeline first
 - Removing tags without checking if other pages use the same tag consistently
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The maintenance report follows this structure:
 
 ```
-## Brain Health Report — YYYY-MM-DD
+## Brain Health Report — YYYY-MM-DD (( inert ))
 
 | Dimension           | Issues Found | Fixed | Remaining |
 |----------------------|-------------|-------|-----------|
@@ -407,13 +407,13 @@
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
