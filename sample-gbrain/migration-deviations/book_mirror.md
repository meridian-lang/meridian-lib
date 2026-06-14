# Deviation: book_mirror.meri

- Original: `book-mirror/SKILL.md`
- Ported: `book_mirror.meri`
- Tier: 3 (structural rewrite)
- Similarity: 49%
- Lines: 351 -> 352 (+180 / -179)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 14/23 inert (61% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=13, template=1
- Judgment: 7 blocks, 108 lines

### Inert section details
- L14 `What this does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L26 `Trust contract (read this before running)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L44 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L74 `2. Text extraction`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L124 `Quality check`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L135 `3. Context gathering`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L140 `What to pull`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L218 `Model: Opus by default`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L225 `Cost gate`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L241 `6. Fact-check and cross-link`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L262 `Quality bar (the bar)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L283 `Anti-patterns (do not do these)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L309 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L330 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/book-mirror/SKILL.md
+++ skills/book_mirror.meri
@@ -26,7 +26,7 @@
 > for the lookup chain (brain → search → external) the context-gathering
 > phase follows.
 
-## What this does
+## What this does (( inert ))
 
 Given a book (EPUB or PDF), produce a brain page where every chapter is
 summarized in detail on the left and mirrored back to the reader's actual life
@@ -38,7 +38,7 @@
 margins. If the user wants a flat summary instead, route them to a different
 skill.
 
-## Trust contract (read this before running)
+## Trust contract (read this before running) (( inert ))
 
 book-mirror runs as a CLI command (`gbrain book-mirror`), NOT as a pure
 markdown skill that the agent dispatches via tools. The CLI is the trusted
@@ -56,7 +56,7 @@
   `people/*` page. The trust narrowing happens at the tool allowlist,
   not at the slug-prefix layer.
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 1. ACQUIRE   → User has the EPUB/PDF locally (manual; book-acquisition is
@@ -68,91 +68,91 @@
 6. PDF       → Optional: render via skills/brain-pdf for delivery.
 ```
 
-## 1. Acquiring the book
-
-book-acquisition (legal-grey-area downloader) was deliberately not shipped
-in this skill wave. The user drops the EPUB/PDF manually. Common paths the
-user might use:
-
-```bash
-# User-supplied path
-ls path/to/book.epub
-ls path/to/book.pdf
-
-# Or already in the brain repo (recommended for tracking)
-ls $BRAIN_DIR/media/books/
-```
-
-Resolve `$BRAIN_DIR` from the gbrain config (`gbrain config get sync.repo_path`)
-or accept it from the user.
-
-## 2. Text extraction
+## 1. Acquiring the book (( role: procedure ))
+
+use judgment to follow the 1. Acquiring the book guidance:
+  book-acquisition (legal-grey-area downloader) was deliberately not shipped
+  in this skill wave. The user drops the EPUB/PDF manually. Common paths the
+  user might use:
+  
+  ```bash
+  # User-supplied path
+  ls path/to/book.epub
+  ls path/to/book.pdf
+  
+  # Or already in the brain repo (recommended for tracking)
+  ls $BRAIN_DIR/media/books/
+  ```
+  
+  Resolve `$BRAIN_DIR` from the gbrain config (`gbrain config get sync.repo_path`)
+  or accept it from the user.
+## 2. Text extraction (( inert ))
 
 Goal: one `.txt` file per chapter under a temp directory. The agent has
 shell + python access; the CLI is downstream of this and takes the
 extracted directory as input.
 
-### EPUB
-
-```bash
-SLUG="this-book"                                # kebab-case
-WORK="$(mktemp -d)/$SLUG"
-mkdir -p "$WORK/chapters"
-unzip -o path/to/book.epub -d "$WORK/unpacked"
-
-# Find content files (XHTML/HTML), sorted (chapter order = sort order)
-find "$WORK/unpacked" -name "*.xhtml" -o -name "*.html" | sort > "$WORK/files.txt"
-
-# Strip HTML to text per chapter
-python3 - <<'PY'
-from bs4 import BeautifulSoup
-import os, sys
-work = os.environ['WORK']
-files = open(f'{work}/files.txt').read().splitlines()
-for i, path in enumerate(files, 1):
-    html = open(path, encoding='utf-8', errors='replace').read()
-    text = BeautifulSoup(html, 'html.parser').get_text('\n')
-    text = '\n'.join(line.strip() for line in text.splitlines() if line.strip())
-    with open(f'{work}/chapters/{i:02d}.txt', 'w') as f:
-        f.write(text)
-PY
-```
-
-If `bs4` is missing: `pip3 install beautifulsoup4 lxml`.
-
-Inspect the chapter files to identify which are real chapters vs front
-matter (TOC, copyright, acknowledgments). Often the EPUB ships one file
-per chapter; sometimes multiple chapters per file. Use
-`head -5 "$WORK/chapters/"*.txt` to spot-check.
-
-### PDF
-
-```bash
-pdftotext -layout path/to/book.pdf "$WORK/full.txt"
-```
-
-Then split by chapter heading (look for "Chapter N", "CHAPTER N", or
-all-caps title lines) using `awk` or `python`. If the PDF is a scan with
-no embedded text, fall back to OCR via `skills/brain-pdf` or another
-vision tool.
-
-### Quality check
-
+### EPUB (( role: procedure ))
+
+use judgment to follow the EPUB guidance:
+  ```bash
+  SLUG="this-book"                                # kebab-case
+  WORK="$(mktemp -d)/$SLUG"
+  mkdir -p "$WORK/chapters"
+  unzip -o path/to/book.epub -d "$WORK/unpacked"
+  
+  # Find content files (XHTML/HTML), sorted (chapter order = sort order)
+  find "$WORK/unpacked" -name "*.xhtml" -o -name "*.html" | sort > "$WORK/files.txt"
+  
+  # Strip HTML to text per chapter
+  python3 - <<'PY'
+  from bs4 import BeautifulSoup
+  import os, sys
+  work = os.environ['WORK']
+  files = open(f'{work}/files.txt').read().splitlines()
+  for i, path in enumerate(files, 1):
+      html = open(path, encoding='utf-8', errors='replace').read()
+      text = BeautifulSoup(html, 'html.parser').get_text('\n')
+      text = '\n'.join(line.strip() for line in text.splitlines() if line.strip())
+      with open(f'{work}/chapters/{i:02d}.txt', 'w') as f:
+          f.write(text)
+  PY
+  ```
+  
+  If `bs4` is missing: `pip3 install beautifulsoup4 lxml`.
+  
+  Inspect the chapter files to identify which are real chapters vs front
+  matter (TOC, copyright, acknowledgments). Often the EPUB ships one file
+  per chapter; sometimes multiple chapters per file. Use
+  `head -5 "$WORK/chapters/"*.txt` to spot-check.
+### PDF (( role: procedure ))
+  
+use judgment to follow the PDF guidance:
+  ```bash
+  pdftotext -layout path/to/book.pdf "$WORK/full.txt"
+  ```
+  
+  Then split by chapter heading (look for "Chapter N", "CHAPTER N", or
+  all-caps title lines) using `awk` or `python`. If the PDF is a scan with
+  no embedded text, fall back to OCR via `skills/brain-pdf` or another
+  vision tool.
+### Quality check (( inert ))
+  
 For each chapter file:
-
-- Word count > 1500 (typical chapter range 2k–8k words).
-- No HTML tags.
-- Paragraphs preserved with `\n\n`.
-
+  
+  item: Word count > 1500 (typical chapter range 2k–8k words).
+  item: No HTML tags.
+  item: Paragraphs preserved with `\n\n`.
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
@@ -170,90 +170,90 @@
 5. **Standing patterns** — anything in the user's reflections or
    originals that's been recurring.
 
-### Assemble a context pack
-
-Write everything to a single file the CLI can read:
-
-```bash
-CONTEXT="$WORK/context.md"
-{
-  echo "## USER.md (if any)"
-  [ -f "$BRAIN_DIR/USER.md" ] && cat "$BRAIN_DIR/USER.md"
-  echo
-  echo "## SOUL.md (if any)"
-  [ -f "$BRAIN_DIR/SOUL.md" ] && cat "$BRAIN_DIR/SOUL.md"
-  echo
-  echo "## Recent reflections (last 14 days)"
-  # Pull recent daily reflections — adapt to the user's filing scheme
-  # ...
-  echo
-  echo "## Topic-relevant brain pages"
-  # gbrain query the book's key themes, embed top results
-  # ...
-  echo
-  echo "## Themes & cruxes"
-  # A 1-page summary, written by the agent, calling out:
-  # - What's currently active in the user's life that this book intersects
-  # - Specific quotes from the user that map to book themes
-  # - People and dates that should appear in the right column
-} > "$CONTEXT"
-```
-
-Make this dense. It's read by every chapter subagent.
-
-## 4. Analysis: invoke `gbrain book-mirror`
-
-```bash
-gbrain book-mirror \
-  --chapters-dir "$WORK/chapters" \
-  --context-file "$CONTEXT" \
-  --slug "$SLUG" \
-  --title "Book Title Goes Here" \
-  --author "Author Name" \
-  --model claude-opus-4-7
-```
-
-The CLI:
-
-- Validates inputs and loads chapter files.
-- Prints a cost estimate (~$0.30/chapter at Opus) and prompts to confirm.
-- Submits N child subagent jobs with read-only `allowed_tools`.
-- Waits for every child to complete.
-- Reads each child's `job.result` (the markdown analysis text).
-- Assembles all chapters into one page with frontmatter + intro + per-chapter
-  sections + closing.
-- Writes ONE `put_page` to `media/books/<slug>-personalized.md`.
-- Reports a JSON envelope on stdout:
-  `{"slug": "...", "chapters_total": N, "chapters_completed": N, "chapters_failed": 0}`.
-
-If any chapter failed, the CLI exits 1 and the user can re-run — idempotency
-keys (`book-mirror:<slug>:ch-<N>`) deduplicate completed chapters at the
-queue level, so retry is cheap.
-
-### Model: Opus by default
-
+### Assemble a context pack (( role: procedure ))
+
+use judgment to follow the Assemble a context pack guidance:
+  Write everything to a single file the CLI can read:
+  
+  ```bash
+  CONTEXT="$WORK/context.md"
+  {
+    echo "## USER.md (if any)"
+    [ -f "$BRAIN_DIR/USER.md" ] && cat "$BRAIN_DIR/USER.md"
+    echo
+    echo "## SOUL.md (if any)"
+    [ -f "$BRAIN_DIR/SOUL.md" ] && cat "$BRAIN_DIR/SOUL.md"
+    echo
+    echo "## Recent reflections (last 14 days)"
+    # Pull recent daily reflections — adapt to the user's filing scheme
+    # ...
+    echo
+    echo "## Topic-relevant brain pages"
+    # gbrain query the book's key themes, embed top results
+    # ...
+    echo
+    echo "## Themes & cruxes"
+    # A 1-page summary, written by the agent, calling out:
+    # - What's currently active in the user's life that this book intersects
+    # - Specific quotes from the user that map to book themes
+    # - People and dates that should appear in the right column
+  } > "$CONTEXT"
+  ```
+  
+  Make this dense. It's read by every chapter subagent.
+## 4. Analysis: invoke `gbrain book-mirror` (( role: procedure ))
+
+use judgment to follow the 4. Analysis: invoke `gbrain book-mirror` guidance:
+  ```bash
+  gbrain book-mirror \
+    --chapters-dir "$WORK/chapters" \
+    --context-file "$CONTEXT" \
+    --slug "$SLUG" \
+    --title "Book Title Goes Here" \
+    --author "Author Name" \
+    --model claude-opus-4-7
+  ```
+  
+  The CLI:
+  
+  item: Validates inputs and loads chapter files.
+  item: Prints a cost estimate (~$0.30/chapter at Opus) and prompts to confirm.
+  item: Submits N child subagent jobs with read-only `allowed_tools`.
+  item: Waits for every child to complete.
+  item: Reads each child's `job.result` (the markdown analysis text).
+  item: Assembles all chapters into one page with frontmatter + intro + per-chapter
+    sections + closing.
+  item: Writes ONE `put_page` to `media/books/<slug>-personalized.md`.
+  item: Reports a JSON envelope on stdout:
+    `{"slug": "...", "chapters_total": N, "chapters_completed": N, "chapters_failed": 0}`.
+  
+  If any chapter failed, the CLI exits 1 and the user can re-run — idempotency
+  keys (`book-mirror:<slug>:ch-<N>`) deduplicate completed chapters at the
+  queue level, so retry is cheap.
+### Model: Opus by default (( inert ))
+  
 The default model is `claude-opus-4-7`. Sonnet works (use `--model
 claude-sonnet-4-6`) but the right-column quality drops noticeably — the
 texture that makes the analysis read like a therapist who knows the user
 needs Opus-grade reasoning.
-
-### Cost gate
-
+  
+### Cost gate (( inert ))
+  
 The CLI refuses to spend in a non-TTY context without `--yes`. CI / scripted
 invocations must pass `--yes` explicitly. TTY users get a `[y/N]` prompt
 before submission.
 
-## 5. PDF (optional)
-
-After the brain page is written, render to PDF using `skills/brain-pdf`:
-
-```bash
-gbrain put_page  # already done by the CLI; nothing to add here
-# Then invoke brain-pdf:
-# (see skills/brain-pdf/SKILL.md for the make-pdf invocation)
-```
-
-## 6. Fact-check and cross-link
+## 5. PDF (optional) (( role: procedure ))
+
+use judgment to follow the 5. PDF (optional) guidance:
+  After the brain page is written, render to PDF using `skills/brain-pdf`:
+  
+  ```bash
+  gbrain put_page  # already done by the CLI; nothing to add here
+  # Then invoke brain-pdf:
+  # (see skills/brain-pdf/SKILL.md for the make-pdf invocation)
+  ```
+## 6. Fact-check and cross-link (( inert ))
 
 After the page lands, run a fact-check pass on factual claims about the
 reader (parents, siblings, marriage history, jobs, heritage). Common error
@@ -274,7 +274,7 @@
   back-link from `people/<slug>` to the new `media/books/<slug>-personalized`
   page (per `conventions/quality.md` Iron Law).
 
-## Quality bar (the bar)
+## Quality bar (the bar) (( inert ))
 
 The **left column** should:
 
@@ -295,7 +295,7 @@
 the reader's actual life rather than a generic profile, and honest about
 where the book's framing breaks down for this specific reader.
 
-## Anti-patterns (do not do these)
+## Anti-patterns (do not do these) (( inert ))
 
 - ❌ **Skimming chapters.** Standing instruction: preserve detail.
 - ❌ **Generic right column.** "This might apply if you've ever felt…" →
@@ -310,18 +310,18 @@
 - ❌ **Truncating the LEFT column.** The book's actual content needs to
   survive.
 
-## Output checklist
-
-- [ ] Book file exists locally (path known).
-- [ ] Chapter texts under `$WORK/chapters/*.txt` with sane word counts.
-- [ ] Context pack at `$WORK/context.md` is dense.
-- [ ] `gbrain book-mirror --chapters-dir … --context-file … --slug … --title …` returned exit 0.
-- [ ] `media/books/<slug>-personalized.md` exists in the brain.
-- [ ] Fact-check pass complete (no errors against USER.md or other source-of-truth pages).
-- [ ] Cross-links added from referenced people/companies.
-- [ ] Optional: PDF rendered via brain-pdf and delivered.
-
-## Related skills
+## Output checklist (( role: procedure ))
+
+use judgment to follow the Output checklist guidance:
+  item: [ ] Book file exists locally (path known).
+  item: [ ] Chapter texts under `$WORK/chapters/*.txt` with sane word counts.
+  item: [ ] Context pack at `$WORK/context.md` is dense.
+  item: [ ] `gbrain book-mirror --chapters-dir … --context-file … --slug … --title …` returned exit 0.
+  item: [ ] `media/books/<slug>-personalized.md` exists in the brain.
+  item: [ ] Fact-check pass complete (no errors against USER.md or other source-of-truth pages).
+  item: [ ] Cross-links added from referenced people/companies.
+  item: [ ] Optional: PDF rendered via brain-pdf and delivered.
+## Related skills (( inert ))
 
 - `skills/brain-pdf/SKILL.md` — render the personalized page to PDF.
 - `skills/strategic-reading/SKILL.md` — read a book through a specific
@@ -330,22 +330,23 @@
   rather than books.
 
 
-## Contract
-
-This skill guarantees:
-
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
-
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+
+!!! checklist (( ai-autonomy ))
+- [ ] Routing matches the canonical triggers in the frontmatter.
+- [ ] Output written under the directories listed in `writes_to:` (when applicable).
+- [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+- [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+
+> The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
 ## Output Format
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
-## Anti-Patterns
-
-The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
-
+## Anti-Patterns (( role: procedure ))
+
+> The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
+
```
