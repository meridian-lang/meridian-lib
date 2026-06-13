# Deviation: book_mirror.meri

- Original: `book-mirror/SKILL.md`
- Ported: `book_mirror.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 351 -> 351 (+22 / -22)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 23/23 inert (100% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/book-mirror/SKILL.md
+++ book_mirror.meri
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
@@ -68,7 +68,7 @@
 6. PDF       → Optional: render via skills/brain-pdf for delivery.
 ```
 
-## 1. Acquiring the book
+## 1. Acquiring the book (( inert ))
 
 book-acquisition (legal-grey-area downloader) was deliberately not shipped
 in this skill wave. The user drops the EPUB/PDF manually. Common paths the
@@ -86,13 +86,13 @@
 Resolve `$BRAIN_DIR` from the gbrain config (`gbrain config get sync.repo_path`)
 or accept it from the user.
 
-## 2. Text extraction
+## 2. Text extraction (( inert ))
 
 Goal: one `.txt` file per chapter under a temp directory. The agent has
 shell + python access; the CLI is downstream of this and takes the
 extracted directory as input.
 
-### EPUB
+### EPUB (( inert ))
 
 ```bash
 SLUG="this-book"                                # kebab-case
@@ -125,7 +125,7 @@
 per chapter; sometimes multiple chapters per file. Use
 `head -5 "$WORK/chapters/"*.txt` to spot-check.
 
-### PDF
+### PDF (( inert ))
 
 ```bash
 pdftotext -layout path/to/book.pdf "$WORK/full.txt"
@@ -136,7 +136,7 @@
 no embedded text, fall back to OCR via `skills/brain-pdf` or another
 vision tool.
 
-### Quality check
+### Quality check (( inert ))
 
 For each chapter file:
 
@@ -147,12 +147,12 @@
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
@@ -170,7 +170,7 @@
 5. **Standing patterns** — anything in the user's reflections or
    originals that's been recurring.
 
-### Assemble a context pack
+### Assemble a context pack (( inert ))
 
 Write everything to a single file the CLI can read:
 
@@ -201,7 +201,7 @@
 
 Make this dense. It's read by every chapter subagent.
 
-## 4. Analysis: invoke `gbrain book-mirror`
+## 4. Analysis: invoke `gbrain book-mirror` (( inert ))
 
 ```bash
 gbrain book-mirror \
@@ -230,20 +230,20 @@
 keys (`book-mirror:<slug>:ch-<N>`) deduplicate completed chapters at the
 queue level, so retry is cheap.
 
-### Model: Opus by default
+### Model: Opus by default (( inert ))
 
 The default model is `claude-opus-4-7`. Sonnet works (use `--model
 claude-sonnet-4-6`) but the right-column quality drops noticeably — the
 texture that makes the analysis read like a therapist who knows the user
 needs Opus-grade reasoning.
 
-### Cost gate
+### Cost gate (( inert ))
 
 The CLI refuses to spend in a non-TTY context without `--yes`. CI / scripted
 invocations must pass `--yes` explicitly. TTY users get a `[y/N]` prompt
 before submission.
 
-## 5. PDF (optional)
+## 5. PDF (optional) (( inert ))
 
 After the brain page is written, render to PDF using `skills/brain-pdf`:
 
@@ -253,7 +253,7 @@
 # (see skills/brain-pdf/SKILL.md for the make-pdf invocation)
 ```
 
-## 6. Fact-check and cross-link
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
@@ -310,7 +310,7 @@
 - ❌ **Truncating the LEFT column.** The book's actual content needs to
   survive.
 
-## Output checklist
+## Output checklist (( inert ))
 
 - [ ] Book file exists locally (path known).
 - [ ] Chapter texts under `$WORK/chapters/*.txt` with sane word counts.
@@ -321,7 +321,7 @@
 - [ ] Cross-links added from referenced people/companies.
 - [ ] Optional: PDF rendered via brain-pdf and delivered.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/brain-pdf/SKILL.md` — render the personalized page to PDF.
 - `skills/strategic-reading/SKILL.md` — read a book through a specific
@@ -330,7 +330,7 @@
   rather than books.
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
@@ -345,7 +345,7 @@
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
 
```
