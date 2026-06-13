# Deviation: capture.meri

- Original: `capture/SKILL.md`
- Ported: `capture.meri`
- Tier: 1 (near-verbatim)
- Similarity: 91%
- Lines: 106 -> 106 (+10 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 6/8 inert (75% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/capture/SKILL.md
+++ capture.meri
@@ -14,12 +14,12 @@
 
 # capture — the single ingestion entrypoint
 
-When the user wants to save a thought, an article snippet, a transcript
-fragment, or any text into their brain, run `gbrain capture`. Don't reach
-for `gbrain put` or commit-then-sync — `capture` is the front door and it
-handles both local and thin-client installs the same way.
+> When the user wants to save a thought, an article snippet, a transcript
+> fragment, or any text into their brain, run `gbrain capture`. Don't reach
+> for `gbrain put` or commit-then-sync — `capture` is the front door and it
+> handles both local and thin-client installs the same way.
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 - **Input:** the content to save (inline arg, `--file PATH`, or `--stdin`).
 - **Output:** a page in the brain DB AND a markdown file on disk under
@@ -37,7 +37,7 @@
 - The user pastes content and asks to keep it
 - After a meeting summary, a research note, or any synthesis that should land as a brain page
 
-## What it does
+## What it does (( inert ))
 
 `gbrain capture` resolves to a `put_page` call (local) or a remote MCP call
 (thin-client). Either way the page lands in the DB AND on disk in one move
@@ -45,7 +45,7 @@
 `inbox/YYYY-MM-DD-<hash8>` so captures cluster in a predictable triage
 location.
 
-## How to use
+## How to use (( role: procedure ))
 
 ```bash
 gbrain capture "the thought I want to remember"
@@ -57,7 +57,7 @@
 gbrain capture "..." --json           # structured output for agents
 ```
 
-## Defaults
+## Defaults (( inert ))
 
 - **Slug:** `inbox/YYYY-MM-DD-<hash8>` (stable for same content; the daemon's 24h dedup catches re-captures).
 - **Type:** `note` (override with `--type idea` etc.).
@@ -80,7 +80,7 @@
 `--quiet` prints only the slug (use for `SLUG=$(gbrain capture "..." --quiet)`).
 `--json` prints structured output for downstream tools.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Don't reach for `gbrain put`.** That's the old per-page primitive that
   doesn't know about default slug generation, content-type heuristics, or
@@ -95,7 +95,7 @@
 - **Don't pass secrets as inline content.** Inline args land in shell
   history. Use `--file` or `--stdin` instead.
 
-## When NOT to use this skill
+## When NOT to use this skill (( inert ))
 
 - Bulk ingestion of many files → `skills/media-ingest/SKILL.md` or `gbrain sync` instead
 - Article/link with author + publication metadata → `skills/idea-ingest/SKILL.md` (it knows to build the people page)
```
