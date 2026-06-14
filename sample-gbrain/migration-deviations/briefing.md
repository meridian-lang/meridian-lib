# Deviation: briefing.meri

- Original: `briefing/SKILL.md`
- Ported: `briefing.meri`
- Tier: 2 (light edits)
- Similarity: 52%
- Lines: 153 -> 129 (+55 / -79)

## Frontmatter
- Added: (none)
- Removed: `tools`

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 5/13 inert (38% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=1, tools-metadata=1
- Judgment: 2 blocks, 6 lines

### Inert section details
- L28 `GBrain-Native Context Loading`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L46 `Before an email reply`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L61 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L98 `Citation in Briefings`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L113 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/briefing/SKILL.md
+++ skills/briefing.meri
@@ -5,99 +5,67 @@
   - "daily briefing"
   - "morning briefing"
   - "what's happening today"
-tools:
-  - search
-  - query
-  - get_page
-  - list_pages
-  - get_timeline
 mutating: false
 ---
 
 # Briefing Skill
 
-Compile a daily briefing from brain context.
+> Compile a daily briefing from brain context.
 
 > **Filing rule:** When the briefing creates or updates brain pages,
 > follow `skills/_brain-filing-rules.md`.
 
-## Contract
+## Contract (( role: procedure ))
 
-- Every fact in the briefing includes an inline `[Source: slug, updated DATE]` citation.
-- Meeting participants are resolved against the brain; gaps are explicitly flagged.
-- Active deals and action items include deadlines and recency context.
-- The briefing is read-only: no brain pages are created or modified unless the user explicitly requests it.
-- Stale alerts surface pages relevant to today's context, not just all stale pages.
+!!! checklist (( ai-autonomy ))
+- [ ] Every fact in the briefing includes an inline `[Source: slug, updated DATE]` citation.
+- [ ] Meeting participants are resolved against the brain; gaps are explicitly flagged.
+- [ ] Active deals and action items include deadlines and recency context.
+- [ ] The briefing is read-only: no brain pages are created or modified unless the user explicitly requests it.
+- [ ] Stale alerts surface pages relevant to today's context, not just all stale pages.
 
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
+  Summarize today's meetings with the participant context loaded below.
 
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
+### Before a meeting (( role: procedure ))
 
-For every attendee on the calendar invite:
-- `gbrain search "<attendee name>"` -- find their brain page
-- `gbrain get <slug>` -- load compiled truth, recent timeline, relationship context
-- If no page exists, note the gap ("No brain page for Sarah Chen -- consider enrichment")
+For every attendee:
+  - `gbrain search "{the attendee's name}"` -- find their brain page
+  - `gbrain get {the attendee's slug}` -- load compiled truth, recent timeline, relationship context
+  > If no page exists, note the gap and consider enrichment.
 
-### Before an email reply
+### Daily briefing queries (( role: procedure ))
 
-Before drafting or triaging any email:
-- `gbrain search "<sender name>"` -- load sender context
-- Read their compiled truth to understand who they are, what they care about, and
-  your relationship history. This turns a cold reply into an informed one.
-
-### Daily briefing queries
-
-Run these queries to populate the briefing sections:
 - `gbrain query "active deals status"` -- deal pipeline snapshot
 - `gbrain query "meetings this week"` -- recent meeting pages with insights
 - `gbrain query "pending commitments follow-ups"` -- open threads and action items
 - `gbrain search --type person --sort updated --limit 10` -- people in play
+
+### Before an email reply (( inert ))
+
+Before drafting or triaging any email, load sender context from the brain and
+read their compiled truth. This turns a cold reply into an informed one.
+
+## Freshness guard
+
+> Surface today's high-priority and empty pages so the briefing flags them
+> instead of presenting stale context as current.
+
+bind pages = invoke list pages with filter = "today".
+let mine be the pages written by the input.
+if any urgent pages or any unwritten pages,
+  emit briefing.attention with status = "needs review".
 
 ## Output Format
 
@@ -123,25 +91,33 @@
 - [name] -- [why they're active]
 ```
 
-## Back-Linking During Briefing
+## Back-Linking During Briefing (( role: procedure ))
 
-If the briefing creates or updates any brain pages (e.g., new meeting prep
-pages, updated entity pages), the back-linking iron law applies: every entity
-mentioned must have a back-link from their page. See `skills/_brain-filing-rules.md`.
+use judgment to follow the Back-Linking During Briefing guidance:
+  If the briefing creates or updates any brain pages (e.g., new meeting prep
+  pages, updated entity pages), the back-linking iron law applies: every entity
+  the page mentions must have a back-link from their page. See
+  `skills/_brain-filing-rules.md`.
+### Enforce back-links
+  
+let mentioned be the entities mentioned by the input.
+for each entity in mentioned:
+  if the entity does not link to the input, add a back-link from the entity to the input.
 
-## Citation in Briefings
+## Citation in Briefings (( inert ))
 
 When presenting facts from brain pages, include inline citations:
 - "Jane is CTO of Acme [Source: people/jane-doe, updated 2026-04-01]"
 - This lets the user trace any claim back to the brain page and assess freshness
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- **Briefing without brain queries.** Never generate a briefing from memory alone; always query gbrain for current data.
-- **Uncited facts.** Every claim must include `[Source: slug, updated DATE]`. A fact without a citation is unverifiable.
-- **Stale context presented as current.** If a page hasn't been updated in 30+ days, flag the staleness explicitly rather than presenting it as fresh.
-- **Modifying brain pages unprompted.** The briefing is read-only by default. Do not create or update pages unless the user explicitly requests it.
-- **Ignoring coverage gaps.** When a meeting participant has no brain page, say so. Silence about gaps hides ignorance.
+!!! checklist (( ai-autonomy ))
+- [ ] **Briefing without brain queries.** Never generate a briefing from memory alone; always query gbrain for current data.
+- [ ] **Uncited facts.** Every claim must include `[Source: slug, updated DATE]`. A fact without a citation is unverifiable.
+- [ ] **Stale context presented as current.** If a page hasn't been updated in 30+ days, flag the staleness explicitly rather than presenting it as fresh.
+- [ ] **Modifying brain pages unprompted.** The briefing is read-only by default. Do not create or update pages unless the user explicitly requests it.
+- [ ] **Ignoring coverage gaps.** When a meeting participant has no brain page, say so. Silence about gaps hides ignorance.
 
 ## Tools Used
 
```
