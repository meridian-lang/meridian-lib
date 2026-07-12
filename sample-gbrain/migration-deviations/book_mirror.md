# Deviation: book_mirror.meri

- Original: `book-mirror/SKILL.md`
- Ported: `book_mirror.meri`
- Tier: 2 (light edits)
- Similarity: 73%
- Lines: 351 -> 419 (+139 / -71)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L53 `The pipeline`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L165 `3. Context gathering`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L320 `Quality bar (the bar)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L386 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L397 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L401 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 281 non-blank ported lines
- Sections inert total: 17/19 (89% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=16, template=1
- Judgment: 2 blocks, 0 lines
- canonical_drift: synonym=9, structure=0, desugar=0, meaning=295

### Inert section details
- L14 `What this does`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L29 `Trust contract (read this before running)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `The pipeline`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L65 `1. Acquiring the book`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L95 `EPUB`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L134 `PDF`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L148 `Quality check`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L165 `3. Context gathering`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L170 `What to pull`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L194 `Assemble a context pack`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L228 `4. Analysis: invoke `gbrain book-mirror``: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L296 `6. Fact-check and cross-link`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L320 `Quality bar (the bar)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L341 `Anti-patterns (do not do these)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L386 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L397 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L401 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/book-mirror/SKILL.md
+++ skills/book_mirror.meri
@@ -26,37 +26,46 @@
 > for the lookup chain (brain → search → external) the context-gathering
 > phase follows.
 
-## What this does
+## What this does (( role: reference ))
+
+This is NOT a generic book summary. The right column is the value: it makes
+the book read like a therapist who knows the reader is leaving notes in the
+margins. If the user wants a flat summary instead, route them to a different
+skill.
+
+
+### What this does — steps (( role: reference ))
 
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
+## Trust contract (read this before running) (( role: reference ))
 
 book-mirror runs as a CLI command (`gbrain book-mirror`), NOT as a pure
 markdown skill that the agent dispatches via tools. The CLI is the trusted
 runtime; the skill is the orchestration prose around it.
 
-What this means for the agent:
+- The CLI reads each child's `job.result`, assembles the final
+  two-column page, and writes it via a single operator-trust `put_page`.
+
+### Trust contract (read this before running) — steps (( role: reference ))
+
+> What this means for the agent:
 
 - The CLI submits N read-only subagent jobs (one per chapter). Each subagent
   has `allowed_tools: ['get_page', 'search']` only. They CANNOT call
   put_page or any mutating op. They produce markdown analysis via their
   final message.
-- The CLI reads each child's `job.result`, assembles the final
-  two-column page, and writes it via a single operator-trust `put_page`.
+
+### Trust contract (read this before running) — steps 2 (( role: reference ))
+
 - This means untrusted EPUB/PDF content cannot prompt-inject any
   `people/*` page. The trust narrowing happens at the tool allowlist,
   not at the slug-prefix layer.
 
-## The pipeline
+## The pipeline (( role: reference ))
 
 ```
 1. ACQUIRE   → User has the EPUB/PDF locally (manual; book-acquisition is
@@ -68,11 +77,17 @@
 6. PDF       → Optional: render via skills/brain-pdf for delivery.
 ```
 
-## 1. Acquiring the book
-
-book-acquisition (legal-grey-area downloader) was deliberately not shipped
-in this skill wave. The user drops the EPUB/PDF manually. Common paths the
-user might use:
+## 1. Acquiring the book (( role: reference ))
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
@@ -83,16 +98,21 @@
 ls $BRAIN_DIR/media/books/
 ```
 
-Resolve `$BRAIN_DIR` from the gbrain config (`gbrain config get sync.repo_path`)
-or accept it from the user.
-
 ## 2. Text extraction
+
+
+### 2. Text extraction — steps (( role: reference ))
 
 Goal: one `.txt` file per chapter under a temp directory. The agent has
 shell + python access; the CLI is downstream of this and takes the
 extracted directory as input.
 
-### EPUB
+### EPUB (( role: reference ))
+
+If `bs4` is missing: `pip3 install beautifulsoup4 lxml`.
+
+
+### EPUB — steps
 
 ```bash
 SLUG="this-book"                                # kebab-case
@@ -108,71 +128,92 @@
 from bs4 import BeautifulSoup
 import os, sys
 work = os.environ['WORK']
-files = open(f'{work}/files.txt').read().splitlines()
+files = open(f'{{work}}/files.txt').read().splitlines()
 for i, path in enumerate(files, 1):
     html = open(path, encoding='utf-8', errors='replace').read()
     text = BeautifulSoup(html, 'html.parser').get_text('\n')
     text = '\n'.join(line.strip() for line in text.splitlines() if line.strip())
-    with open(f'{work}/chapters/{i:02d}.txt', 'w') as f:
+    with open(f'{{work}}/chapters/{{i:02d}}.txt', 'w') as f:
         f.write(text)
 PY
 ```
 
-If `bs4` is missing: `pip3 install beautifulsoup4 lxml`.
+
+### EPUB — steps 2 (( role: reference ))
 
 Inspect the chapter files to identify which are real chapters vs front
 matter (TOC, copyright, acknowledgments). Often the EPUB ships one file
 per chapter; sometimes multiple chapters per file. Use
 `head -5 "$WORK/chapters/"*.txt` to spot-check.
 
-### PDF
-
-```bash
-pdftotext -layout path/to/book.pdf "$WORK/full.txt"
-```
+### PDF (( role: reference ))
 
 Then split by chapter heading (look for "Chapter N", "CHAPTER N", or
 all-caps title lines) using `awk` or `python`. If the PDF is a scan with
 no embedded text, fall back to OCR via `skills/brain-pdf` or another
 vision tool.
 
-### Quality check
-
-For each chapter file:
+
+### PDF — steps
+
+```bash
+pdftotext -layout path/to/book.pdf "$WORK/full.txt"
+```
+
+### Quality check (( role: reference ))
 
 - Word count > 1500 (typical chapter range 2k–8k words).
 - No HTML tags.
 - Paragraphs preserved with `\n\n`.
 
+
+### Quality check — steps (( role: reference ))
+
+For each chapter file:
+
+
+### Quality check — steps 2 (( role: reference ))
+
 Save a `chapters/INDEX.md` mapping chapter number → title → file → word
 count for reference.
 
-## 3. Context gathering
+## 3. Context gathering (( role: reference ))
 
 This is the most critical step. The right column is only as good as the
 context fed to each chapter subagent.
 
-### What to pull
+### What to pull (( role: reference ))
 
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
+### What to pull — steps (( role: reference ))
+
+2. Recent daily memory — last 14 days of brain pages under
+   `wiki/personal/reflections/` or wherever the user files daily notes.
+
+### What to pull — steps 2 (( role: reference ))
+
+4. Brain pages for relevant entities — `gbrain query "<name>"` for
+   people who will likely come up.
+### Assemble a context pack (( role: reference ))
+
+Make this dense. It's read by every chapter subagent.
+
+
+### Assemble a context pack — steps
+
+> Write everything to a single file the CLI can read:
 
 ```bash
 CONTEXT="$WORK/context.md"
@@ -199,9 +240,23 @@
 } > "$CONTEXT"
 ```
 
-Make this dense. It's read by every chapter subagent.
-
-## 4. Analysis: invoke `gbrain book-mirror`
+## 4. Analysis: invoke `gbrain book-mirror` (( role: reference ))
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
@@ -213,31 +268,31 @@
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
 ### Model: Opus by default
 
-The default model is `claude-opus-4-7`. Sonnet works (use `--model
-claude-sonnet-4-6`) but the right-column quality drops noticeably — the
+
+### Model: Opus by default — steps
+
+use judgment to follow the Model: Opus by default — steps guidance:
+The default model is `claude-opus-4-7`. Sonnet works (use ``--model
+claude-sonnet-4-6``) but the right-column quality drops noticeably — the
 texture that makes the analysis read like a therapist who knows the user
 needs Opus-grade reasoning.
 
 ### Cost gate
+
+
+### Cost gate — steps
 
 The CLI refuses to spend in a non-TTY context without `--yes`. CI / scripted
 invocations must pass `--yes` explicitly. TTY users get a `[y/N]` prompt
@@ -253,7 +308,7 @@
 # (see skills/brain-pdf/SKILL.md for the make-pdf invocation)
 ```
 
-## 6. Fact-check and cross-link
+## 6. Fact-check and cross-link (( role: reference ))
 
 After the page lands, run a fact-check pass on factual claims about the
 reader (parents, siblings, marriage history, jobs, heritage). Common error
@@ -268,13 +323,16 @@
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
+## Quality bar (the bar) (( role: reference ))
 
 The **left column** should:
 
@@ -295,21 +353,28 @@
 the reader's actual life rather than a generic profile, and honest about
 where the book's framing breaks down for this specific reader.
 
-## Anti-patterns (do not do these)
+## Anti-patterns (do not do these) (( role: reference ))
 
 - ❌ **Skimming chapters.** Standing instruction: preserve detail.
 - ❌ **Generic right column.** "This might apply if you've ever felt…" →
   kill on sight.
-- ❌ **Factual errors about the reader's life.** Always fact-check after
-  assembly.
 - ❌ **Giving the subagent put_page access.** Trust contract is read-only;
   the CLI does the writing.
 - ❌ **Forcing connections.** If a chapter doesn't apply, say so plainly.
+- ❌ **Truncating the LEFT column.** The book's actual content needs to
+  survive.
+
+
+### Anti-patterns (do not do these) — steps
+
+- ❌ Factual errors about the reader's life. Always fact-check after
+  assembly.
+
+### Anti-patterns (do not do these) — steps 2
+
+use judgment to follow the Anti-patterns (do not do these) — steps 2 guidance:
 - ❌ **Sycophancy or moralizing in the right column.** No "you should…",
   no "consider…", no "perhaps it's time to…".
-- ❌ **Truncating the LEFT column.** The book's actual content needs to
-  survive.
-
 ## Output checklist
 
 - [ ] Book file exists locally (path known).
@@ -323,6 +388,9 @@
 
 ## Related skills
 
+
+### Related skills — steps
+
 - `skills/brain-pdf/SKILL.md` — render the personalized page to PDF.
 - `skills/strategic-reading/SKILL.md` — read a book through a specific
   problem-lens instead of personalizing to the whole reader.
@@ -330,7 +398,7 @@
   rather than books.
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -341,11 +409,11 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
 
```
