# Deviation: capture.meri

- Original: `capture/SKILL.md`
- Ported: `capture.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 106 -> 113 (+28 / -21)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L9 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L27 `What it does`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Defaults`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 6/8 (75% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=5, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=78

### Inert section details
- L9 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L27 `What it does`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `Defaults`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L70 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L89 `When NOT to use this skill`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/capture/SKILL.md
+++ skills/capture.meri
@@ -14,21 +14,21 @@
 
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
+## Contract (( role: reference ))
 
-- **Input:** the content to save (inline arg, `--file PATH`, or `--stdin`).
-- **Output:** a page in the brain DB AND a markdown file on disk under
+- Input: the content to save (inline arg, `--file PATH`, or `--stdin`).
+- Output: a page in the brain DB AND a markdown file on disk under
   `<sync.repo_path>/<slug>.md`. Receipt printed to stdout.
-- **Side effect:** the page becomes immediately queryable via `gbrain query`,
+- Side effect: the page becomes immediately queryable via `gbrain query`,
   `gbrain search`, or any MCP-bound agent.
-- **Idempotency:** same content → same `inbox/YYYY-MM-DD-<hash8>` slug. The
+- Idempotency: same content → same `inbox/YYYY-MM-DD-<hash8>` slug. The
   daemon's 24h content-hash dedup catches re-captures.
-- **Trust:** all captures via this skill are local-CLI trust (`remote: false`).
+- Trust: all captures via this skill are local-CLI trust (`remote: false`).
   Untrusted webhook ingestion goes through `POST /ingest`, not this verb.
 
 ## When to invoke
@@ -37,7 +37,7 @@
 - The user pastes content and asks to keep it
 - After a meeting summary, a research note, or any synthesis that should land as a brain page
 
-## What it does
+## What it does (( role: reference ))
 
 `gbrain capture` resolves to a `put_page` call (local) or a remote MCP call
 (thin-client). Either way the page lands in the DB AND on disk in one move
@@ -57,14 +57,14 @@
 gbrain capture "..." --json           # structured output for agents
 ```
 
-## Defaults
+## Defaults (( role: reference ))
 
 - **Slug:** `inbox/YYYY-MM-DD-<hash8>` (stable for same content; the daemon's 24h dedup catches re-captures).
 - **Type:** `note` (override with `--type idea` etc.).
 - **Frontmatter stamps:** `captured_via: capture-cli`, `captured_at: <ISO>`.
 - **Title:** first non-empty line of the body, capped at 80 chars.
 
-## Output Format
+## Output Format (( role: template ))
 
 Default prints a 5-line receipt:
 
@@ -80,27 +80,34 @@
 `--quiet` prints only the slug (use for `SLUG=$(gbrain capture "..." --quiet)`).
 `--json` prints structured output for downstream tools.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
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
+### Anti-Patterns — steps
+
+- Don't try to bulk-import dozens of files by looping over `gbrain capture`. That's what `gbrain sync` (or `gbrain import`) is for. Capture is for single thoughts, single notes, single transcripts.
+
+### Anti-Patterns — steps 2
+
+  Pass `--file PATH` if you already have a fully-formatted markdown file.
+## When NOT to use this skill (( role: reference ))
 
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
