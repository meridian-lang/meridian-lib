# Deviation: brain_pdf.meri

- Original: `brain-pdf/SKILL.md`
- Ported: `brain_pdf.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 187 -> 187 (+11 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

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
@@ -33,7 +33,7 @@
 - Producing a briefing or report with running headers and page numbers
 - Archiving a long-form essay in a portable format
 
-## Prerequisite: gstack make-pdf
+## Prerequisite: gstack make-pdf (( inert ))
 
 This skill depends on the gstack `make-pdf` binary at:
 
@@ -64,7 +64,7 @@
               they fail silently).
 ```
 
-## Invocation
+## Invocation (( inert ))
 
 ```bash
 SLUG="path/to/page"
@@ -99,7 +99,7 @@
 `CONTAINER=1` is mandatory in containerized environments — it tells
 Playwright to skip Chromium sandboxing. Harmless on bare-metal.
 
-## Common patterns
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
 
@@ -149,7 +149,7 @@
 can also see it on GitHub / locally. The PDF is a rendering; the source
 is the artifact.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ Generating a PDF without first confirming the brain page exists.
   No source = no PDF.
@@ -161,7 +161,7 @@
 - ❌ Using raw `MEDIA:` tags for Telegram delivery. Use the `message`
   tool with `filePath`.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/book-mirror/SKILL.md` — produces a brain page that's a
   natural input to brain-pdf (chapter-by-chapter personalized analysis).
@@ -170,7 +170,7 @@
   HTML (different rendering target).
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
```
