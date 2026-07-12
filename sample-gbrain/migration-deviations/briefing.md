# Deviation: briefing.meri

- Original: `briefing/SKILL.md`
- Ported: `briefing.meri`
- Tier: 2 (light edits)
- Similarity: 67%
- Lines: 153 -> 201 (+83 / -35)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L83 `GBrain-Native Context Loading`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L119 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L179 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- generated_loc: 121 non-blank ported lines
- Sections inert total: 7/8 (88% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=5, template=1, tools-metadata=1
- Judgment: 3 blocks, 3 lines
- canonical_drift: synonym=7, structure=0, desugar=0, meaning=130

### Inert section details
- L9 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L20 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `GBrain-Native Context Loading`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L119 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L152 `Citation in Briefings`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L165 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L179 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/briefing/SKILL.md
+++ skills/briefing.meri
@@ -16,38 +16,28 @@
 
 # Briefing Skill
 
-Compile a daily briefing from brain context.
+> Compile a daily briefing from brain context.
 
 > **Filing rule:** When the briefing creates or updates brain pages,
 > follow `skills/_brain-filing-rules.md`.
 
-## Contract
-
-- Every fact in the briefing includes an inline `[Source: slug, updated DATE]` citation.
+## Contract (( role: reference ))
+
 - Meeting participants are resolved against the brain; gaps are explicitly flagged.
 - Active deals and action items include deadlines and recency context.
 - The briefing is read-only: no brain pages are created or modified unless the user explicitly requests it.
 - Stale alerts surface pages relevant to today's context, not just all stale pages.
 
-## Phases
-
-0. **Hot memory pulse (v0.32).** Before composing anything else, run:
-
-   ```bash
-   gbrain recall --since-last-run --supersessions --pending --rollup --json
-   ```
-
-   Fold the result into the briefing under a "Brain pulse" section at the top:
-   1. **Contradictions resolved overnight** — the `--supersessions` output. Lead
-      with these because they're new corrections to your model of the world.
+
+### Contract — steps
+
+- Every fact in the briefing includes an inline `[Source: slug, updated DATE]` citation.
+## Phases (( role: reference ))
+
    2. **Top mentions** — `top_entities` from `--rollup` (top 5 entity slugs by
       fact count in the window).
    3. **New facts since last briefing** — group the `facts` array under each
       entity from the rollup; include `kind`, `notability`, and `confidence`.
-   4. **Pending consolidation footer** — when `pending_consolidation_count > 0`,
-      note `N facts await dream-cycle consolidation` so the operator can decide
-      whether to run `gbrain dream` before reading further.
-
    The `--since-last-run` flag advances `~/.gbrain/recall-cursors/<source>.json`
    so the next briefing picks up exactly where this one left off. If you're
    running this as a cron job, pass `--source <slug>` or set `GBRAIN_SOURCE`
@@ -55,25 +45,57 @@
    may miss the right source. Thin-client installs (`gbrain init --mcp-only`)
    route through the remote brain transparently.
 
-1. **Today's meetings.** For each meeting on the calendar:
    - Search gbrain for each participant by name
    - Read their pages from gbrain for compiled_truth context
    - Summarize: who they are, recent timeline, relationship to you
-2. **Active deals.** List deal pages in gbrain filtered to active status:
-   - Deadlines approaching in the next 7 days
    - Recent timeline entries (last 7 days)
-3. **Time-sensitive threads.** Open items from timeline entries:
-   - Items with deadlines in the next 48 hours
    - Follow-ups that are overdue
 4. **Recent changes.** Pages updated in the last 24 hours:
    - What changed and why (read timeline entries from gbrain)
-5. **People in play.** List person pages in gbrain sorted by recency:
    - Updated in last 7 days
    - Have high activity (many recent timeline entries)
 6. **Stale alerts.** From gbrain health check:
    - Pages flagged as stale that are relevant to today's meetings
 
-## GBrain-Native Context Loading
+
+### Phases — steps
+
+> 0. **Hot memory pulse (v0.32).** Before composing anything else, run:
+
+   ```bash
+   gbrain recall --since-last-run --supersessions --pending --rollup --json
+   ```
+
+> Fold the result into the briefing under a "Brain pulse" section at the top:
+   1. Contradictions resolved overnight — the `--supersessions` output. Lead
+      with these because they're new corrections to your model of the world.
+
+### Phases — steps 2
+
+use judgment to follow the Phases — steps 2 guidance:
+   4. **Pending consolidation footer** — when `pending_consolidation_count > 0`,
+      note `N facts await dream-cycle consolidation` so the operator can decide
+      whether to run `gbrain dream` before reading further.
+
+
+### Phases — steps 3
+
+1. For each meeting on the calendar:
+
+### Phases — steps 4
+
+2. List deal pages in gbrain filtered to active status:
+   - Deadlines approaching in the next 7 days
+
+### Phases — steps 5
+
+> 3. **Time-sensitive threads.** Open items from timeline entries:
+   - Items with deadlines in the next 48 hours
+
+### Phases — steps 6
+
+5. List person pages in gbrain sorted by recency:
+## GBrain-Native Context Loading (( role: reference ))
 
 Before generating any briefing, load context from gbrain systematically.
 
@@ -86,14 +108,24 @@
 
 ### Before an email reply
 
-Before drafting or triaging any email:
+
+### Before an email reply — steps
+
+> Before drafting or triaging any email:
 - `gbrain search "<sender name>"` -- load sender context
+
+### Before an email reply — steps 2
+
+use judgment to follow the Before an email reply — steps 2 guidance:
 - Read their compiled truth to understand who they are, what they care about, and
   your relationship history. This turns a cold reply into an informed one.
 
 ### Daily briefing queries
 
-Run these queries to populate the briefing sections:
+
+### Daily briefing queries — steps
+
+> Run these queries to populate the briefing sections:
 - `gbrain query "active deals status"` -- deal pipeline snapshot
 - `gbrain query "meetings this week"` -- recent meeting pages with insights
 - `gbrain query "pending commitments follow-ups"` -- open threads and action items
@@ -125,23 +157,39 @@
 
 ## Back-Linking During Briefing
 
+
+### Back-Linking During Briefing — steps
+
 If the briefing creates or updates any brain pages (e.g., new meeting prep
 pages, updated entity pages), the back-linking iron law applies: every entity
 mentioned must have a back-link from their page. See `skills/_brain-filing-rules.md`.
 
-## Citation in Briefings
+## Citation in Briefings (( role: reference ))
+
+- "Jane is CTO of Acme [Source: people/jane-doe, updated 2026-04-01]"
+
+### Citation in Briefings — steps (( role: reference ))
 
 When presenting facts from brain pages, include inline citations:
-- "Jane is CTO of Acme [Source: people/jane-doe, updated 2026-04-01]"
+
+### Citation in Briefings — steps 2
+
+use judgment to follow the Citation in Briefings — steps 2 guidance:
 - This lets the user trace any claim back to the brain page and assess freshness
 
-## Anti-Patterns
-
-- **Briefing without brain queries.** Never generate a briefing from memory alone; always query gbrain for current data.
-- **Uncited facts.** Every claim must include `[Source: slug, updated DATE]`. A fact without a citation is unverifiable.
+## Anti-Patterns (( role: reference ))
+
 - **Stale context presented as current.** If a page hasn't been updated in 30+ days, flag the staleness explicitly rather than presenting it as fresh.
 - **Modifying brain pages unprompted.** The briefing is read-only by default. Do not create or update pages unless the user explicitly requests it.
-- **Ignoring coverage gaps.** When a meeting participant has no brain page, say so. Silence about gaps hides ignorance.
+
+### Anti-Patterns — steps (( role: reference ))
+
+- Never generate a briefing from memory alone; always query gbrain for current data.
+- Uncited facts. Every claim must include `[Source: slug, updated DATE]`. A fact without a citation is unverifiable.
+
+### Anti-Patterns — steps 2 (( role: reference ))
+
+- When a meeting participant has no brain page, say so. Silence about gaps hides ignorance.
 
 ## Tools Used
 
```
