# Deviation: briefing.meri

- Original: `briefing/SKILL.md`
- Ported: `briefing.meri`
- Tier: 2 (light edits)
- Similarity: 76%
- Lines: 153 -> 180 (+53 / -26)

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
- L78 `GBrain-Native Context Loading`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L110 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L143 `Citation in Briefings`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L158 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 5/9 (56% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=1, tools-metadata=1
- Judgment: 3 blocks, 18 lines

### Inert section details
- L78 `GBrain-Native Context Loading`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L89 `Before an email reply`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L110 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L143 `Citation in Briefings`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L158 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/briefing/SKILL.md
+++ skills/briefing.meri
@@ -16,12 +16,13 @@
 
 # Briefing Skill
 
-Compile a daily briefing from brain context.
+> Compile a daily briefing from brain context.
 
 > **Filing rule:** When the briefing creates or updates brain pages,
 > follow `skills/_brain-filing-rules.md`.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 - Every fact in the briefing includes an inline `[Source: slug, updated DATE]` citation.
 - Meeting participants are resolved against the brain; gaps are explicitly flagged.
@@ -30,16 +31,8 @@
 - Stale alerts surface pages relevant to today's context, not just all stale pages.
 
 ## Phases
+use judgment to follow the Phases guidance:
 
-0. **Hot memory pulse (v0.32).** Before composing anything else, run:
-
-   ```bash
-   gbrain recall --since-last-run --supersessions --pending --rollup --json
-   ```
-
-   Fold the result into the briefing under a "Brain pulse" section at the top:
-   1. **Contradictions resolved overnight** — the `--supersessions` output. Lead
-      with these because they're new corrections to your model of the world.
    2. **Top mentions** — `top_entities` from `--rollup` (top 5 entity slugs by
       fact count in the window).
    3. **New facts since last briefing** — group the `facts` array under each
@@ -55,25 +48,49 @@
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
+1. For each meeting on the calendar:
+
+### Phases — steps 3
+
+2. List deal pages in gbrain filtered to active status:
+   - Deadlines approaching in the next 7 days
+
+### Phases — steps 4
+
+> 3. **Time-sensitive threads.** Open items from timeline entries:
+   - Items with deadlines in the next 48 hours
+
+### Phases — steps 5
+
+5. List person pages in gbrain sorted by recency:
+## GBrain-Native Context Loading (( inert ))
 
 Before generating any briefing, load context from gbrain systematically.
 
@@ -84,16 +101,22 @@
 - `gbrain get <slug>` -- load compiled truth, recent timeline, relationship context
 - If no page exists, note the gap ("No brain page for Sarah Chen -- consider enrichment")
 
-### Before an email reply
+### Before an email reply (( inert ))
 
-Before drafting or triaging any email:
-- `gbrain search "<sender name>"` -- load sender context
 - Read their compiled truth to understand who they are, what they care about, and
   your relationship history. This turns a cold reply into an informed one.
 
-### Daily briefing queries
 
-Run these queries to populate the briefing sections:
+#### Before an email reply — steps
+
+> Before drafting or triaging any email:
+- `gbrain search "<sender name>"` -- load sender context
+### Daily briefing queries (( inert ))
+
+
+#### Daily briefing queries — steps
+
+> Run these queries to populate the briefing sections:
 - `gbrain query "active deals status"` -- deal pipeline snapshot
 - `gbrain query "meetings this week"` -- recent meeting pages with insights
 - `gbrain query "pending commitments follow-ups"` -- open threads and action items
@@ -123,19 +146,23 @@
 - [name] -- [why they're active]
 ```
 
-## Back-Linking During Briefing
+## Back-Linking During Briefing (( inert ))
+
+
+### Back-Linking During Briefing — steps
 
 If the briefing creates or updates any brain pages (e.g., new meeting prep
 pages, updated entity pages), the back-linking iron law applies: every entity
 mentioned must have a back-link from their page. See `skills/_brain-filing-rules.md`.
 
-## Citation in Briefings
+## Citation in Briefings (( inert ))
 
 When presenting facts from brain pages, include inline citations:
 - "Jane is CTO of Acme [Source: people/jane-doe, updated 2026-04-01]"
 - This lets the user trace any claim back to the brain page and assess freshness
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Briefing without brain queries.** Never generate a briefing from memory alone; always query gbrain for current data.
 - **Uncited facts.** Every claim must include `[Source: slug, updated DATE]`. A fact without a citation is unverifiable.
```
