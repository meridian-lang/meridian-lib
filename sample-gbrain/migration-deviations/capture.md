# Deviation: capture.meri

- Original: `capture/SKILL.md`
- Ported: `capture.meri`
- Tier: 1 (near-verbatim)
- Similarity: 86%
- Lines: 106 -> 106 (+15 / -15)

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
- L21 `When to invoke`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L27 `What it does`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L47 `Defaults`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L54 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L70 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L85 `When NOT to use this skill`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 7/8 inert (88% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=4, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L9 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L21 `When to invoke`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L27 `What it does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L47 `Defaults`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L54 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L70 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L85 `When NOT to use this skill`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/capture/SKILL.md
+++ skills/capture.meri
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
@@ -31,13 +31,13 @@
 - **Trust:** all captures via this skill are local-CLI trust (`remote: false`).
   Untrusted webhook ingestion goes through `POST /ingest`, not this verb.
 
-## When to invoke
+## When to invoke (( inert, role: applicability ))
 
 - "Capture this thought" / "save this" / "drop this into my brain" / "remember this"
 - The user pastes content and asks to keep it
 - After a meeting summary, a research note, or any synthesis that should land as a brain page
 
-## What it does
+## What it does (( inert ))
 
 `gbrain capture` resolves to a `put_page` call (local) or a remote MCP call
 (thin-client). Either way the page lands in the DB AND on disk in one move
@@ -57,14 +57,14 @@
 gbrain capture "..." --json           # structured output for agents
 ```
 
-## Defaults
+## Defaults (( inert ))
 
-- **Slug:** `inbox/YYYY-MM-DD-<hash8>` (stable for same content; the daemon's 24h dedup catches re-captures).
-- **Type:** `note` (override with `--type idea` etc.).
-- **Frontmatter stamps:** `captured_via: capture-cli`, `captured_at: <ISO>`.
-- **Title:** first non-empty line of the body, capped at 80 chars.
+- Slug: `inbox/YYYY-MM-DD-<hash8>` (stable for same content; the daemon's 24h dedup catches re-captures).
+- Type: `note` (override with `--type idea` etc.).
+- Frontmatter stamps: `captured_via: capture-cli`, `captured_at: <ISO>`.
+- Title: first non-empty line of the body, capped at 80 chars.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Default prints a 5-line receipt:
 
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
