# Deviation: book_mirror.meri

- Original: `book-mirror/SKILL.md`
- Ported: `book_mirror.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 351 -> 410 (+125 / -66)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L54 `The pipeline`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L166 `3. Context gathering`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L267 `Model: Opus by default`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L315 `Quality bar (the bar)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L387 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 14/21 (67% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=13, template=1
- Judgment: 5 blocks, 0 lines

### Inert section details
- L30 `Trust contract (read this before running)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L54 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L66 `1. Acquiring the book`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L96 `EPUB`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L135 `PDF`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L149 `Quality check`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L166 `3. Context gathering`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L171 `What to pull`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L195 `Assemble a context pack`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L229 `4. Analysis: invoke `gbrain book-mirror``: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L267 `Model: Opus by default`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L291 `6. Fact-check and cross-link`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L315 `Quality bar (the bar)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L387 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/book-mirror/SKILL.md
+++ skills/book_mirror.meri
@@ -27,36 +27,46 @@
 > phase follows.
 
 ## What this does
+use judgment to follow the What this does guidance:
+
+This is NOT a generic book summary. The right column is the value: it makes
+the book read like a therapist who knows the reader is leaving notes in the
+margins. If the user wants a flat summary instead, route them to a different
+skill.
+
+
+### What this does — steps
 
 Given a book (EPUB or PDF), produce a brain page where every chapter is
 summarized in detail on the left and mirrored back to the reader's actual life
 on the right, using their own words, situations, people, and patterns from
 the brain. Output is a brain page at `media/books/<slug>-personalized.md`.
 
-This is NOT a generic book summary. The right column is the value: it makes
-the book read like a therapist who knows the reader is leaving notes in the
-margins. If the user wants a flat summary instead, route them to a different
-skill.
-
-## Trust contract (read this before running)
+## Trust contract (read this before running) (( inert ))
 
 book-mirror runs as a CLI command (`gbrain book-mirror`), NOT as a pure
 markdown skill that the agent dispatches via tools. The CLI is the trusted
 runtime; the skill is the orchestration prose around it.
 
-What this means for the agent:
+- The CLI reads each child's `job.result`, assembles the final
+  two-column page, and writes it via a single operator-trust `put_page`.
+
+### Trust contract (read this before running) — steps
+
+> What this means for the agent:
 
 - The CLI submits N read-only subagent jobs (one per chapter). Each subagent
   has `allowed_tools: ['get_page', 'search']` only. They CANNOT call
   put_page or any mutating op. They produce markdown analysis via their
   final message.
-- The CLI reads each child's `job.result`, assembles the final
-  two-column page, and writes it via a single operator-trust `put_page`.
+
+### Trust contract (read this before running) — steps 2
+
 - This means untrusted EPUB/PDF content cannot prompt-inject any
   `people/*` page. The trust narrowing happens at the tool allowlist,
   not at the slug-prefix layer.
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 1. ACQUIRE   → User has the EPUB/PDF locally (manual; book-acquisition is
@@ -68,11 +78,17 @@
 6. PDF       → Optional: render via skills/brain-pdf for delivery.
 ```
 
-## 1. Acquiring the book
-
-book-acquisition (legal-grey-area downloader) was deliberately not shipped
-in this skill wave. The user drops the EPUB/PDF manually. Common paths the
-user might use:
+## 1. Acquiring the book (( inert ))
+
+Resolve `$BRAIN_DIR` from the gbrain config (`gbrain config get sync.repo_path`)
+or accept it from the user.
+
+
+### 1. Acquiring the book — steps
+
+> book-acquisition (legal-grey-area downloader) was deliberately not shipped
+> in this skill wave. The user drops the EPUB/PDF manually. Common paths the
+> user might use:
 
 ```bash
 # User-supplied path
@@ -83,16 +99,21 @@
 ls $BRAIN_DIR/media/books/
 ```
 
-Resolve `$BRAIN_DIR` from the gbrain config (`gbrain config get sync.repo_path`)
-or accept it from the user.
-
-## 2. Text extraction
+## 2. Text extraction (( inert ))
+
+
+### 2. Text extraction — steps
 
 Goal: one `.txt` file per chapter under a temp directory. The agent has
 shell + python access; the CLI is downstream of this and takes the
 extracted directory as input.
 
-### EPUB
+### EPUB (( inert ))
+
+If `bs4` is missing: `pip3 install beautifulsoup4 lxml`.
+
+
+#### EPUB — steps
 
 ```bash
 SLUG="this-book"                                # kebab-case
@@ -118,61 +139,82 @@
 PY
 ```
 
-If `bs4` is missing: `pip3 install beautifulsoup4 lxml`.
+
+#### EPUB — steps 2
 
 Inspect the chapter files to identify which are real chapters vs front
 matter (TOC, copyright, acknowledgments). Often the EPUB ships one file
 per chapter; sometimes multiple chapters per file. Use
 `head -5 "$WORK/chapters/"*.txt` to spot-check.
 
-### PDF
-
-```bash
-pdftotext -layout path/to/book.pdf "$WORK/full.txt"
-```
+### PDF (( inert ))
 
 Then split by chapter heading (look for "Chapter N", "CHAPTER N", or
 all-caps title lines) using `awk` or `python`. If the PDF is a scan with
 no embedded text, fall back to OCR via `skills/brain-pdf` or another
 vision tool.
 
-### Quality check
-
-For each chapter file:
+
+#### PDF — steps
+
+```bash
+pdftotext -layout path/to/book.pdf "$WORK/full.txt"
+```
+
+### Quality check (( inert ))
 
 - Word count > 1500 (typical chapter range 2k–8k words).
 - No HTML tags.
 - Paragraphs preserved with `\n\n`.
 
+
+#### Quality check — steps
+
+For each chapter file:
+
+
+#### Quality check — steps 2
+
 Save a `chapters/INDEX.md` mapping chapter number → title → file → word
 count for reference.
 
-## 3. Context gathering
+## 3. Context gathering (( inert ))
 
 This is the most critical step. The right column is only as good as the
 context fed to each chapter subagent.
 
-### What to pull
+### What to pull (( inert ))
 
 1. **Templates: USER.md and SOUL.md** if the user maintains them
    (gbrain ships templates at `templates/USER.md` and `templates/SOUL.md`;
    they live in the brain repo when populated). Read full.
-2. **Recent daily memory** — last 14 days of brain pages under
-   `wiki/personal/reflections/` or wherever the user files daily notes.
 3. **Topic-relevant brain searches** tuned to the book's themes:
    - `gbrain query "marriage"`, `gbrain query "couples therapy"` for a
      marriage book.
    - `gbrain query "founders"`, `gbrain query "fundraising"` for a
      business book.
    - `gbrain query "shame"`, `gbrain query "anger"` for a psychology book.
-4. **Brain pages for relevant entities** — `gbrain query "<name>"` for
-   people who will likely come up.
 5. **Standing patterns** — anything in the user's reflections or
    originals that's been recurring.
 
-### Assemble a context pack
-
-Write everything to a single file the CLI can read:
+
+#### What to pull — steps
+
+2. Recent daily memory — last 14 days of brain pages under
+   `wiki/personal/reflections/` or wherever the user files daily notes.
+
+#### What to pull — steps 2
+
+4. Brain pages for relevant entities — `gbrain query "<name>"` for
+   people who will likely come up.
+### Assemble a context pack (( inert ))
+
+Make this dense. It's read by every chapter subagent.
+
+
+#### Assemble a context pack — steps
+
+> Write everything to a single file the CLI can read:
 
 ```bash
 CONTEXT="$WORK/context.md"
@@ -199,9 +241,23 @@
 } > "$CONTEXT"
 ```
 
-Make this dense. It's read by every chapter subagent.
-
-## 4. Analysis: invoke `gbrain book-mirror`
+## 4. Analysis: invoke `gbrain book-mirror` (( inert ))
+
+The CLI:
+
+- Validates inputs and loads chapter files.
+- Prints a cost estimate (~$0.30/chapter at Opus) and prompts to confirm.
+- Submits N child subagent jobs with read-only `allowed_tools`.
+- Waits for every child to complete.
+- Assembles all chapters into one page with frontmatter + intro + per-chapter
+  sections + closing.
+- Writes ONE `put_page` to `media/books/<slug>-personalized.md`.
+If any chapter failed, the CLI exits 1 and the user can re-run — idempotency
+keys (`book-mirror:<slug>:ch-<N>`) deduplicate completed chapters at the
+queue level, so retry is cheap.
+
+
+### 4. Analysis: invoke `gbrain book-mirror` — steps
 
 ```bash
 gbrain book-mirror \
@@ -213,31 +269,25 @@
   --model claude-opus-4-7
 ```
 
-The CLI:
-
-- Validates inputs and loads chapter files.
-- Prints a cost estimate (~$0.30/chapter at Opus) and prompts to confirm.
-- Submits N child subagent jobs with read-only `allowed_tools`.
-- Waits for every child to complete.
+
+### 4. Analysis: invoke `gbrain book-mirror` — steps 2
+
 - Reads each child's `job.result` (the markdown analysis text).
-- Assembles all chapters into one page with frontmatter + intro + per-chapter
-  sections + closing.
-- Writes ONE `put_page` to `media/books/<slug>-personalized.md`.
-- Reports a JSON envelope on stdout:
+
+### 4. Analysis: invoke `gbrain book-mirror` — steps 3
+
+> - Reports a JSON envelope on stdout:
   `{"slug": "...", "chapters_total": N, "chapters_completed": N, "chapters_failed": 0}`.
 
-If any chapter failed, the CLI exits 1 and the user can re-run — idempotency
-keys (`book-mirror:<slug>:ch-<N>`) deduplicate completed chapters at the
-queue level, so retry is cheap.
-
-### Model: Opus by default
-
-The default model is `claude-opus-4-7`. Sonnet works (use `--model
-claude-sonnet-4-6`) but the right-column quality drops noticeably — the
+### Model: Opus by default (( inert ))
+
+The default model is `claude-opus-4-7`. Sonnet works (use ``--model
+claude-sonnet-4-6``) but the right-column quality drops noticeably — the
 texture that makes the analysis read like a therapist who knows the user
 needs Opus-grade reasoning.
 
 ### Cost gate
+use judgment to follow the Cost gate guidance:
 
 The CLI refuses to spend in a non-TTY context without `--yes`. CI / scripted
 invocations must pass `--yes` explicitly. TTY users get a `[y/N]` prompt
@@ -253,7 +303,7 @@
 # (see skills/brain-pdf/SKILL.md for the make-pdf invocation)
 ```
 
-## 6. Fact-check and cross-link
+## 6. Fact-check and cross-link (( inert ))
 
 After the page lands, run a fact-check pass on factual claims about the
 reader (parents, siblings, marriage history, jobs, heritage). Common error
@@ -268,13 +318,16 @@
 If you can't verify a claim, remove it. Better to lose texture than to
 introduce a falsehood.
 
-Cross-link entities mentioned in the analysis:
+
+### 6. Fact-check and cross-link — steps
+
+> Cross-link entities mentioned in the analysis:
 
 - For every person the right column references with a brain page, add a
   back-link from `people/<slug>` to the new `media/books/<slug>-personalized`
   page (per `conventions/quality.md` Iron Law).
 
-## Quality bar (the bar)
+## Quality bar (the bar) (( inert ))
 
 The **left column** should:
 
@@ -296,6 +349,7 @@
 where the book's framing breaks down for this specific reader.
 
 ## Anti-patterns (do not do these)
+use judgment to follow the Anti-patterns (do not do these) guidance:
 
 - ❌ **Skimming chapters.** Standing instruction: preserve detail.
 - ❌ **Generic right column.** "This might apply if you've ever felt…" →
@@ -321,7 +375,10 @@
 - [ ] Cross-links added from referenced people/companies.
 - [ ] Optional: PDF rendered via brain-pdf and delivered.
 
-## Related skills
+## Related skills (( inert, role: procedure ))
+
+
+### Related skills — steps
 
 - `skills/brain-pdf/SKILL.md` — render the personalized page to PDF.
 - `skills/strategic-reading/SKILL.md` — read a book through a specific
@@ -330,7 +387,8 @@
   rather than books.
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -341,11 +399,12 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
 
```
