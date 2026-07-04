# Deviation: capture.meri

- Original: `capture/SKILL.md`
- Ported: `capture.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 106 -> 118 (+28 / -16)

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
- L29 `What it does`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L56 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/8 (38% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L29 `What it does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L56 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L94 `When NOT to use this skill`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/capture/SKILL.md
+++ skills/capture.meri
@@ -14,12 +14,13 @@
 
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
+use judgment to follow the Contract guidance:
 
 - **Input:** the content to save (inline arg, `--file PATH`, or `--stdin`).
 - **Output:** a page in the brain DB AND a markdown file on disk under
@@ -31,13 +32,14 @@
 - **Trust:** all captures via this skill are local-CLI trust (`remote: false`).
   Untrusted webhook ingestion goes through `POST /ingest`, not this verb.
 
-## When to invoke
+## When to invoke (( role: procedure ))
+use judgment to follow the When to invoke guidance:
 
 - "Capture this thought" / "save this" / "drop this into my brain" / "remember this"
 - The user pastes content and asks to keep it
 - After a meeting summary, a research note, or any synthesis that should land as a brain page
 
-## What it does
+## What it does (( inert ))
 
 `gbrain capture` resolves to a `put_page` call (local) or a remote MCP call
 (thin-client). Either way the page lands in the DB AND on disk in one move
@@ -64,7 +66,7 @@
 - **Frontmatter stamps:** `captured_via: capture-cli`, `captured_at: <ISO>`.
 - **Title:** first non-empty line of the body, capped at 80 chars.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Default prints a 5-line receipt:
 
@@ -80,27 +82,37 @@
 `--quiet` prints only the slug (use for `SLUG=$(gbrain capture "..." --quiet)`).
 `--json` prints structured output for downstream tools.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - **Don't reach for `gbrain put`.** That's the old per-page primitive that
   doesn't know about default slug generation, content-type heuristics, or
   the receipt block. `capture` is the human-facing wrapper.
-- **Don't try to bulk-import dozens of files by looping over `gbrain capture`.**
-  That's what `gbrain sync` (or `gbrain import`) is for. Capture is for
-  single thoughts, single notes, single transcripts.
 - **Don't pre-format the content yourself with frontmatter if you don't need to.**
   Capture wraps plain prose in sensible frontmatter (type + title +
   captured_via + captured_at). The body becomes `# Title\n\n<your prose>`.
-  Pass `--file PATH` if you already have a fully-formatted markdown file.
 - **Don't pass secrets as inline content.** Inline args land in shell
   history. Use `--file` or `--stdin` instead.
 
-## When NOT to use this skill
+
+### Anti-Patterns — steps (( inert ))
+
+- Don't try to bulk-import dozens of files by looping over `gbrain capture`.
+  That's what `gbrain sync` (or `gbrain import`) is for. Capture is for
+  single thoughts, single notes, single transcripts.
+
+### Anti-Patterns — steps 2
+
+  Pass `--file PATH` if you already have a fully-formatted markdown file.
+## When NOT to use this skill (( inert ))
 
 - Bulk ingestion of many files → `skills/media-ingest/SKILL.md` or `gbrain sync` instead
 - Article/link with author + publication metadata → `skills/idea-ingest/SKILL.md` (it knows to build the people page)
-- Meeting transcripts → `skills/meeting-ingestion/SKILL.md` (attendee enrichment)
-
 This skill is for the simple "I have a thought, save it" case. Specialized
 ingestion paths handle their own slugging + cross-referencing.
 
+
+### When NOT to use this skill — steps
+
+- Meeting transcripts → `skills/meeting-ingestion/SKILL.md` (attendee enrichment)
+
```
