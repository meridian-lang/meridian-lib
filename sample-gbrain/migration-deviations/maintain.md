# Deviation: maintain.meri

- Original: `maintain/SKILL.md`
- Ported: `maintain.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 431 -> 449 (+81 / -63)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 32/33 inert (97% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/maintain/SKILL.md
+++ maintain.meri
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
@@ -50,7 +50,21 @@
 
 ## Phases
 
-### Autonomous path (v0.36.4.0) — when you want to reach a target score
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
+### Autonomous path (v0.36.4.0) — when you want to reach a target score (( inert ))
 
 If the user asks "get my brain to 90/100" or "fix what's broken", prefer the
 one-command loop over walking each dimension by hand:
@@ -76,44 +90,42 @@
 - You're investigating why score is stuck below `--remediate`'s ceiling
 - A specific dimension needs manual judgment that the auto path skips
 
-### Manual path
+### Manual path (( inert ))
 
 1. **Run health check.** Check gbrain health to get the dashboard.
 2. **Check each dimension:**
 
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
+### Dimension reference (( inert ))
+
+The page-level dimensions are now checkable adjectives driven by the
+`Page-health scan` above, not hand-walked prose:
+
+- **Stale** — `compiled truth` is empty (`Definition: a page is stale …`); the
+  assessment hasn't been written to reflect recent evidence.
+- **Orphan** — zero inbound links (`Definition: a page is orphan …`); nobody
+  references the page.
+- **Dead links / missing cross-references** — handled by the executable
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
 
 `gbrain dream` runs the full 8-phase maintenance cycle:
 
@@ -190,7 +202,7 @@
 Parses `- **YYYY-MM-DD** | Source — Summary` and `### YYYY-MM-DD — Title` formats.
 Note: extracted entries improve structured queries (`gbrain timeline`), not vector search.
 
-### Autopilot check
+### Autopilot check (( inert ))
 Verify autopilot is running:
 ```bash
 gbrain autopilot --status
@@ -204,7 +216,7 @@
 Minion job and supervises the worker child — one install step gives you
 sync + extract + embed + backlinks + durable job processing.
 
-### Fix a half-migrated install
+### Fix a half-migrated install (( inert ))
 A v0.11.0 install where the migration skill never fired leaves Minions
 partially set up: schema is applied, but `~/.gbrain/preferences.json`
 doesn't exist, autopilot runs inline, host manifests still reference
@@ -224,7 +236,7 @@
 
 Full troubleshooting guide: `docs/guides/minions-fix.md`.
 
-### Back-link enforcement
+### Back-link enforcement (( inert ))
 Check that the back-linking iron law is being followed:
 - For each recently updated page, check if entities mentioned in it have
   corresponding back-links FROM those entity pages
@@ -232,7 +244,13 @@
 - Fix: add the missing back-link to the entity's Timeline or See Also section
 - Format: `- **YYYY-MM-DD** | Referenced in [page title](path) -- brief context`
 
-### Filing rule violations
+### Repair missing back-links
+
+let mentioned be the entities mentioned by the input.
+for each entity in mentioned:
+  if the entity does not link to the input, add a back-link from the entity to the input.
+
+### Filing rule violations (( inert ))
 Check for common misfiling patterns (see `skills/_brain-filing-rules.md`):
 - Content with clear primary subjects filed in `sources/` instead of the
   appropriate directory (people/, companies/, concepts/, etc.)
@@ -240,18 +258,18 @@
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
@@ -279,22 +297,22 @@
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
@@ -302,11 +320,11 @@
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
@@ -325,18 +343,18 @@
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
@@ -344,18 +362,18 @@
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
@@ -367,13 +385,13 @@
 
 This creates an audit trail for brain health over time.
 
-## Quality Rules
+## Quality Rules (( inert ))
 
 - Never delete pages without confirmation
 - Log all changes via timeline entries
 - Check gbrain health before and after to show improvement
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Fixing pages without reading them first -- you must understand context before editing
 - Silently skipping dimensions -- every dimension must be checked and reported, even if clean
@@ -389,7 +407,7 @@
 The maintenance report follows this structure:
 
 ```
-## Brain Health Report — YYYY-MM-DD
+## Brain Health Report — YYYY-MM-DD (( inert ))
 
 | Dimension           | Issues Found | Fixed | Remaining |
 |----------------------|-------------|-------|-----------|
@@ -407,13 +425,13 @@
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
