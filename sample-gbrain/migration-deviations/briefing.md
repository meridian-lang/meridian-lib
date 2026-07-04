# Deviation: briefing.meri

- Original: `briefing/SKILL.md`
- Ported: `briefing.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 153 -> 153 (+10 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L9 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L17 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L61 `GBrain-Native Context Loading`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L65 `Before a meeting`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L72 `Before an email reply`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L79 `Daily briefing queries`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L87 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L111 `Back-Linking During Briefing`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L117 `Citation in Briefings`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L123 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L131 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections: 11/11 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=7, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L9 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L17 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L61 `GBrain-Native Context Loading`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L65 `Before a meeting`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L72 `Before an email reply`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L79 `Daily briefing queries`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L87 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L111 `Back-Linking During Briefing`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L117 `Citation in Briefings`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L123 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L131 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
@@ -29,7 +29,7 @@
 - The briefing is read-only: no brain pages are created or modified unless the user explicitly requests it.
 - Stale alerts surface pages relevant to today's context, not just all stale pages.
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 0. **Hot memory pulse (v0.32).** Before composing anything else, run:
 
@@ -73,25 +73,25 @@
 6. **Stale alerts.** From gbrain health check:
    - Pages flagged as stale that are relevant to today's meetings
 
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
@@ -123,19 +123,19 @@
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
```
