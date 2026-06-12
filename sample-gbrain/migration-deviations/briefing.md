# Deviation: briefing.meri

- Original: `briefing/SKILL.md`
- Ported: `briefing.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 153 -> 121 (+18 / -50)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Unified diff

```diff
--- original-skills/briefing/SKILL.md
+++ skills/briefing.meri
@@ -16,12 +16,12 @@
 
 # Briefing Skill
 
-Compile a daily briefing from brain context.
+> Compile a daily briefing from brain context.
 
 > **Filing rule:** When the briefing creates or updates brain pages,
 > follow `skills/_brain-filing-rules.md`.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 - Every fact in the briefing includes an inline `[Source: slug, updated DATE]` citation.
 - Meeting participants are resolved against the brain; gaps are explicitly flagged.
@@ -31,67 +31,35 @@
 
 ## Phases
 
-0. **Hot memory pulse (v0.32).** Before composing anything else, run:
+```bash
+gbrain recall --since-last-run --supersessions --pending --rollup --json
+```
 
-   ```bash
-   gbrain recall --since-last-run --supersessions --pending --rollup --json
-   ```
+use judgment to compose the daily briefing:
+  Fold the recall pulse into a "Brain pulse" section: contradictions resolved overnight, top mentions, new facts since the last briefing, and a pending-consolidation footer.
+  Summarize today's meetings with participant context loaded from the brain.
+  List active deals with deadlines approaching in the next seven days and recent timeline entries.
+  Surface time-sensitive threads, recent changes, people in play, and stale alerts relevant to today.
 
-   Fold the result into the briefing under a "Brain pulse" section at the top:
-   1. **Contradictions resolved overnight** — the `--supersessions` output. Lead
-      with these because they're new corrections to your model of the world.
-   2. **Top mentions** — `top_entities` from `--rollup` (top 5 entity slugs by
-      fact count in the window).
-   3. **New facts since last briefing** — group the `facts` array under each
-      entity from the rollup; include `kind`, `notability`, and `confidence`.
-   4. **Pending consolidation footer** — when `pending_consolidation_count > 0`,
-      note `N facts await dream-cycle consolidation` so the operator can decide
-      whether to run `gbrain dream` before reading further.
-
-   The `--since-last-run` flag advances `~/.gbrain/recall-cursors/<source>.json`
-   so the next briefing picks up exactly where this one left off. If you're
-   running this as a cron job, pass `--source <slug>` or set `GBRAIN_SOURCE`
-   explicitly — cron doesn't start in your repo-root cwd, so dotfile resolution
-   may miss the right source. Thin-client installs (`gbrain init --mcp-only`)
-   route through the remote brain transparently.
-
-1. **Today's meetings.** For each meeting on the calendar:
-   - Search gbrain for each participant by name
-   - Read their pages from gbrain for compiled_truth context
-   - Summarize: who they are, recent timeline, relationship to you
-2. **Active deals.** List deal pages in gbrain filtered to active status:
-   - Deadlines approaching in the next 7 days
-   - Recent timeline entries (last 7 days)
-3. **Time-sensitive threads.** Open items from timeline entries:
-   - Items with deadlines in the next 48 hours
-   - Follow-ups that are overdue
-4. **Recent changes.** Pages updated in the last 24 hours:
-   - What changed and why (read timeline entries from gbrain)
-5. **People in play.** List person pages in gbrain sorted by recency:
-   - Updated in last 7 days
-   - Have high activity (many recent timeline entries)
-6. **Stale alerts.** From gbrain health check:
-   - Pages flagged as stale that are relevant to today's meetings
-
-## GBrain-Native Context Loading
+## GBrain-Native Context Loading (( inert ))
 
 Before generating any briefing, load context from gbrain systematically.
 
-### Before a meeting
+### Before a meeting (( inert ))
 
 For every attendee on the calendar invite:
 - `gbrain search "<attendee name>"` -- find their brain page
 - `gbrain get <slug>` -- load compiled truth, recent timeline, relationship context
 - If no page exists, note the gap ("No brain page for Sarah Chen -- consider enrichment")
 
-### Before an email reply
+### Before an email reply (( inert ))
 
 Before drafting or triaging any email:
 - `gbrain search "<sender name>"` -- load sender context
 - Read their compiled truth to understand who they are, what they care about, and
   your relationship history. This turns a cold reply into an informed one.
 
-### Daily briefing queries
+### Daily briefing queries (( inert ))
 
 Run these queries to populate the briefing sections:
 - `gbrain query "active deals status"` -- deal pipeline snapshot
@@ -123,19 +91,19 @@
 - [name] -- [why they're active]
 ```
 
-## Back-Linking During Briefing
+## Back-Linking During Briefing (( inert ))
 
 If the briefing creates or updates any brain pages (e.g., new meeting prep
 pages, updated entity pages), the back-linking iron law applies: every entity
 mentioned must have a back-link from their page. See `skills/_brain-filing-rules.md`.
 
-## Citation in Briefings
+## Citation in Briefings (( inert ))
 
 When presenting facts from brain pages, include inline citations:
 - "Jane is CTO of Acme [Source: people/jane-doe, updated 2026-04-01]"
 - This lets the user trace any claim back to the brain page and assess freshness
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Briefing without brain queries.** Never generate a briefing from memory alone; always query gbrain for current data.
 - **Uncited facts.** Every claim must include `[Source: slug, updated DATE]`. A fact without a citation is unverifiable.
@@ -143,7 +111,7 @@
 - **Modifying brain pages unprompted.** The briefing is read-only by default. Do not create or update pages unless the user explicitly requests it.
 - **Ignoring coverage gaps.** When a meeting participant has no brain page, say so. Silence about gaps hides ignorance.
 
-## Tools Used
+## Tools Used (( inert ))
 
 - Search gbrain by name (query)
 - Read a page from gbrain (get_page)
```
