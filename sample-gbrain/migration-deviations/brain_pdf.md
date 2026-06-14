# Deviation: brain_pdf.meri

- Original: `brain-pdf/SKILL.md`
- Ported: `brain_pdf.meri`
- Tier: 2 (light edits)
- Similarity: 61%
- Lines: 187 -> 189 (+74 / -72)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 7/13 inert (54% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=1
- Judgment: 2 blocks, 38 lines

### Inert section details
- L8 `The rule`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L14 `What this does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L107 `Defaults: NO cover, NO TOC`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L114 `Font requirements`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L127 `Delivery`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L154 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L175 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/brain-pdf/SKILL.md
+++ skills/brain_pdf.meri
@@ -16,13 +16,13 @@
 > output rules. The PDF is a rendering — never the primary artifact. If a
 > PDF exists, the source brain page exists behind it.
 
-## The rule
+## The rule (( inert ))
 
 The brain page is ALWAYS the source of truth. The PDF is a rendering of
 it, never a standalone artifact. If a PDF exists somewhere, the brain
 page must exist behind it.
 
-## What this does
+## What this does (( inert ))
 
 Renders a brain page (markdown with frontmatter) into a
 publication-quality PDF using the gstack `make-pdf` binary. Output is
@@ -33,25 +33,25 @@
 - Producing a briefing or report with running headers and page numbers
 - Archiving a long-form essay in a portable format
 
-## Prerequisite: gstack make-pdf
+## Prerequisite: gstack make-pdf (( role: procedure ))
 
-This skill depends on the gstack `make-pdf` binary at:
-
-```
-$HOME/.claude/skills/gstack/make-pdf/dist/pdf
-```
-
-The user must have gstack co-installed. If absent, the skill cannot run.
-A future v0.26+ may bundle a fallback PDF renderer; for v0.25.1 gstack
-is a soft prereq.
-
-Verify it exists before invoking:
-
-```bash
-P="$HOME/.claude/skills/gstack/make-pdf/dist/pdf"
-[ -x "$P" ] || { echo "make-pdf not installed; install gstack" >&2; exit 1; }
-```
-
+use judgment to follow the Prerequisite: gstack make-pdf guidance:
+  This skill depends on the gstack `make-pdf` binary at:
+  
+  ```
+  $HOME/.claude/skills/gstack/make-pdf/dist/pdf
+  ```
+  
+  The user must have gstack co-installed. If absent, the skill cannot run.
+  A future v0.26+ may bundle a fallback PDF renderer; for v0.25.1 gstack
+  is a soft prereq.
+  
+  Verify it exists before invoking:
+  
+  ```bash
+  P="$HOME/.claude/skills/gstack/make-pdf/dist/pdf"
+  [ -x "$P" ] || { echo "make-pdf not installed; install gstack" >&2; exit 1; }
+  ```
 ## Workflow
 
 ```
@@ -64,42 +64,42 @@
               they fail silently).
 ```
 
-## Invocation
+## Invocation (( role: procedure ))
 
-```bash
-SLUG="path/to/page"
-P="$HOME/.claude/skills/gstack/make-pdf/dist/pdf"
-
-# 1. Confirm the page exists.
-gbrain get "$SLUG" > /dev/null || { echo "Page $SLUG not found" >&2; exit 1; }
-
-# 2. Get the raw markdown. Two paths: read from the brain repo (if user
-#    syncs locally) OR ask gbrain for the body via the API.
-BRAIN_DIR=$(gbrain config get sync.repo_path 2>/dev/null || echo)
-if [ -n "$BRAIN_DIR" ] && [ -f "$BRAIN_DIR/$SLUG.md" ]; then
-  RAW="$BRAIN_DIR/$SLUG.md"
-else
-  RAW=$(mktemp /tmp/brain-page-XXXXXX.md)
-  gbrain get "$SLUG" --raw > "$RAW"   # whatever flag exposes raw body
-fi
-
-# 3. Strip YAML frontmatter — sed: skip the opening '---' through the
-#    closing '---' (lines 1..N), then keep everything after.
-CLEAN=$(mktemp /tmp/brain-page-clean-XXXXXX.md)
-sed '1{/^---$/!q}; /^---$/,/^---$/d' "$RAW" > "$CLEAN"
-
-# 4. Render. NO --cover, NO --toc by default — they look corporate
-#    and waste space. Add them only if explicitly requested.
-OUT="/tmp/$(basename "$SLUG").pdf"
-CONTAINER=1 "$P" generate "$CLEAN" "$OUT"
-
-echo "Rendered: $OUT"
-```
-
-`CONTAINER=1` is mandatory in containerized environments — it tells
-Playwright to skip Chromium sandboxing. Harmless on bare-metal.
-
-## Common patterns
+use judgment to follow the Invocation guidance:
+  ```bash
+  SLUG="path/to/page"
+  P="$HOME/.claude/skills/gstack/make-pdf/dist/pdf"
+  
+  # 1. Confirm the page exists.
+  gbrain get "$SLUG" > /dev/null || { echo "Page $SLUG not found" >&2; exit 1; }
+  
+  # 2. Get the raw markdown. Two paths: read from the brain repo (if user
+  #    syncs locally) OR ask gbrain for the body via the API.
+  BRAIN_DIR=$(gbrain config get sync.repo_path 2>/dev/null || echo)
+  if [ -n "$BRAIN_DIR" ] && [ -f "$BRAIN_DIR/$SLUG.md" ]; then
+    RAW="$BRAIN_DIR/$SLUG.md"
+  else
+    RAW=$(mktemp /tmp/brain-page-XXXXXX.md)
+    gbrain get "$SLUG" --raw > "$RAW"   # whatever flag exposes raw body
+  fi
+  
+  # 3. Strip YAML frontmatter — sed: skip the opening '---' through the
+  #    closing '---' (lines 1..N), then keep everything after.
+  CLEAN=$(mktemp /tmp/brain-page-clean-XXXXXX.md)
+  sed '1{/^---$/!q}; /^---$/,/^---$/d' "$RAW" > "$CLEAN"
+  
+  # 4. Render. NO --cover, NO --toc by default — they look corporate
+  #    and waste space. Add them only if explicitly requested.
+  OUT="/tmp/$(basename "$SLUG").pdf"
+  CONTAINER=1 "$P" generate "$CLEAN" "$OUT"
+  
+  echo "Rendered: $OUT"
+  ```
+  
+  `CONTAINER=1` is mandatory in containerized environments — it tells
+  Playwright to skip Chromium sandboxing. Harmless on bare-metal.
+## Common patterns (( role: procedure ))
 
 ```bash
 # Default — clean PDF, no cover, no TOC
@@ -115,14 +115,14 @@
 CONTAINER=1 "$P" generate --title "Custom Title" --author "Custom Author" "$CLEAN" "$OUT"
 ```
 
-## Defaults: NO cover, NO TOC
+## Defaults: NO cover, NO TOC (( inert ))
 
 These flags are off by default because they look corporate and waste
 space on most personal-knowledge content. Only add them when the user
 explicitly asks for "formal" output (e.g., something they're sending to
 a board or printing as a deliverable).
 
-## Font requirements
+## Font requirements (( inert ))
 
 The renderer needs:
 
@@ -135,7 +135,7 @@
 host's package manager (`apt install fonts-liberation fonts-noto-cjk` on
 Debian/Ubuntu containers).
 
-## Delivery
+## Delivery (( inert ))
 
 After rendering, deliver via the agent's preferred channel:
 
@@ -149,19 +149,20 @@
 can also see it on GitHub / locally. The PDF is a rendering; the source
 is the artifact.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- ❌ Generating a PDF without first confirming the brain page exists.
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ Generating a PDF without first confirming the brain page exists.
   No source = no PDF.
-- ❌ Skipping the frontmatter strip. The renderer dumps frontmatter as
+- [ ] ❌ Skipping the frontmatter strip. The renderer dumps frontmatter as
   raw text on the first page; ugly.
-- ❌ Skipping emoji sanitization. Emoji that don't map to the rendering
+- [ ] ❌ Skipping emoji sanitization. Emoji that don't map to the rendering
   font show up as `□` boxes.
-- ❌ Adding `--cover` or `--toc` by default. Off unless asked.
-- ❌ Using raw `MEDIA:` tags for Telegram delivery. Use the `message`
+- [ ] ❌ Adding `--cover` or `--toc` by default. Off unless asked.
+- [ ] ❌ Using raw `MEDIA:` tags for Telegram delivery. Use the `message`
   tool with `filePath`.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/book-mirror/SKILL.md` — produces a brain page that's a
   natural input to brain-pdf (chapter-by-chapter personalized analysis).
@@ -170,16 +171,17 @@
   HTML (different rendering target).
 
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
+> This skill guarantees:
 
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+!!! checklist (( ai-autonomy ))
+- [ ] Routing matches the canonical triggers in the frontmatter.
+- [ ] Output written under the directories listed in `writes_to:` (when applicable).
+- [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+- [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
 
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+> The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
 ## Output Format
 
```
