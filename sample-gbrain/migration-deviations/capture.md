# Deviation: capture.meri

- Original: `capture/SKILL.md`
- Ported: `capture.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 106 -> 108 (+21 / -19)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 4/8 inert (50% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L28 `What it does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L48 `Defaults`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L55 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L87 `When NOT to use this skill`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/capture/SKILL.md
+++ skills/capture.meri
@@ -14,21 +14,22 @@
 
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
+## Contract (( role: procedure ))
 
-- **Input:** the content to save (inline arg, `--file PATH`, or `--stdin`).
-- **Output:** a page in the brain DB AND a markdown file on disk under
+!!! checklist (( ai-autonomy ))
+- [ ] **Input:** the content to save (inline arg, `--file PATH`, or `--stdin`).
+- [ ] **Output:** a page in the brain DB AND a markdown file on disk under
   `<sync.repo_path>/<slug>.md`. Receipt printed to stdout.
-- **Side effect:** the page becomes immediately queryable via `gbrain query`,
+- [ ] **Side effect:** the page becomes immediately queryable via `gbrain query`,
   `gbrain search`, or any MCP-bound agent.
-- **Idempotency:** same content → same `inbox/YYYY-MM-DD-<hash8>` slug. The
+- [ ] **Idempotency:** same content → same `inbox/YYYY-MM-DD-<hash8>` slug. The
   daemon's 24h content-hash dedup catches re-captures.
-- **Trust:** all captures via this skill are local-CLI trust (`remote: false`).
+- [ ] **Trust:** all captures via this skill are local-CLI trust (`remote: false`).
   Untrusted webhook ingestion goes through `POST /ingest`, not this verb.
 
 ## When to invoke
@@ -37,7 +38,7 @@
 - The user pastes content and asks to keep it
 - After a meeting summary, a research note, or any synthesis that should land as a brain page
 
-## What it does
+## What it does (( inert ))
 
 `gbrain capture` resolves to a `put_page` call (local) or a remote MCP call
 (thin-client). Either way the page lands in the DB AND on disk in one move
@@ -45,7 +46,7 @@
 `inbox/YYYY-MM-DD-<hash8>` so captures cluster in a predictable triage
 location.
 
-## How to use
+## How to use (( role: procedure ))
 
 ```bash
 gbrain capture "the thought I want to remember"
@@ -57,7 +58,7 @@
 gbrain capture "..." --json           # structured output for agents
 ```
 
-## Defaults
+## Defaults (( inert ))
 
 - **Slug:** `inbox/YYYY-MM-DD-<hash8>` (stable for same content; the daemon's 24h dedup catches re-captures).
 - **Type:** `note` (override with `--type idea` etc.).
@@ -80,22 +81,23 @@
 `--quiet` prints only the slug (use for `SLUG=$(gbrain capture "..." --quiet)`).
 `--json` prints structured output for downstream tools.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- **Don't reach for `gbrain put`.** That's the old per-page primitive that
+!!! checklist (( ai-autonomy ))
+- [ ] **Don't reach for `gbrain put`.** That's the old per-page primitive that
   doesn't know about default slug generation, content-type heuristics, or
   the receipt block. `capture` is the human-facing wrapper.
-- **Don't try to bulk-import dozens of files by looping over `gbrain capture`.**
+- [ ] **Don't try to bulk-import dozens of files by looping over `gbrain capture`.**
   That's what `gbrain sync` (or `gbrain import`) is for. Capture is for
   single thoughts, single notes, single transcripts.
-- **Don't pre-format the content yourself with frontmatter if you don't need to.**
+- [ ] **Don't pre-format the content yourself with frontmatter if you don't need to.**
   Capture wraps plain prose in sensible frontmatter (type + title +
   captured_via + captured_at). The body becomes `# Title\n\n<your prose>`.
   Pass `--file PATH` if you already have a fully-formatted markdown file.
-- **Don't pass secrets as inline content.** Inline args land in shell
+- [ ] **Don't pass secrets as inline content.** Inline args land in shell
   history. Use `--file` or `--stdin` instead.
 
-## When NOT to use this skill
+## When NOT to use this skill (( inert ))
 
 - Bulk ingestion of many files → `skills/media-ingest/SKILL.md` or `gbrain sync` instead
 - Article/link with author + publication metadata → `skills/idea-ingest/SKILL.md` (it knows to build the people page)
```
