# Deviation: brain_pdf.meri

- Original: `brain-pdf/SKILL.md`
- Ported: `brain_pdf.meri`
- Tier: 1 (near-verbatim)
- Similarity: 85%
- Lines: 187 -> 209 (+40 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L120 `Defaults: NO cover, NO TOC`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L195 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/12 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 7 blocks, 0 lines

### Inert section details
- L66 `Invocation`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L120 `Defaults: NO cover, NO TOC`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L127 `Font requirements`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L195 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/brain-pdf/SKILL.md
+++ skills/brain_pdf.meri
@@ -17,12 +17,14 @@
 > PDF exists, the source brain page exists behind it.
 
 ## The rule
+use judgment to follow the The rule guidance:
 
 The brain page is ALWAYS the source of truth. The PDF is a rendering of
 it, never a standalone artifact. If a PDF exists somewhere, the brain
 page must exist behind it.
 
 ## What this does
+use judgment to follow the What this does guidance:
 
 Renders a brain page (markdown with frontmatter) into a
 publication-quality PDF using the gstack `make-pdf` binary. Output is
@@ -34,8 +36,7 @@
 - Archiving a long-form essay in a portable format
 
 ## Prerequisite: gstack make-pdf
-
-This skill depends on the gstack `make-pdf` binary at:
+use judgment to follow the Prerequisite: gstack make-pdf guidance:
 
 ```
 $HOME/.claude/skills/gstack/make-pdf/dist/pdf
@@ -45,7 +46,15 @@
 A future v0.26+ may bundle a fallback PDF renderer; for v0.25.1 gstack
 is a soft prereq.
 
-Verify it exists before invoking:
+
+### Prerequisite: gstack make-pdf — steps
+
+This skill depends on the gstack `make-pdf` binary at:
+
+
+### Prerequisite: gstack make-pdf — steps 2
+
+> Verify it exists before invoking:
 
 ```bash
 P="$HOME/.claude/skills/gstack/make-pdf/dist/pdf"
@@ -53,6 +62,7 @@
 ```
 
 ## Workflow
+use judgment to follow the Workflow guidance:
 
 ```
 1. RESOLVE  → Confirm the brain page exists (gbrain get <slug>).
@@ -64,7 +74,13 @@
               they fail silently).
 ```
 
-## Invocation
+## Invocation (( inert ))
+
+`CONTAINER=1` is mandatory in containerized environments — it tells
+Playwright to skip Chromium sandboxing. Harmless on bare-metal.
+
+
+### Invocation — steps
 
 ```bash
 SLUG="path/to/page"
@@ -96,9 +112,6 @@
 echo "Rendered: $OUT"
 ```
 
-`CONTAINER=1` is mandatory in containerized environments — it tells
-Playwright to skip Chromium sandboxing. Harmless on bare-metal.
-
 ## Common patterns
 
 ```bash
@@ -115,19 +128,15 @@
 CONTAINER=1 "$P" generate --title "Custom Title" --author "Custom Author" "$CLEAN" "$OUT"
 ```
 
-## Defaults: NO cover, NO TOC
+## Defaults: NO cover, NO TOC (( inert ))
 
 These flags are off by default because they look corporate and waste
 space on most personal-knowledge content. Only add them when the user
 explicitly asks for "formal" output (e.g., something they're sending to
 a board or printing as a deliverable).
 
-## Font requirements
-
-The renderer needs:
-
-- `fonts-liberation` (Helvetica/Arial substitute)
-- `fonts-noto-cjk` (Chinese/Japanese/Korean characters)
+## Font requirements (( inert ))
+
 - Minimum body font size: 10pt (page chrome 9pt)
 - Body text: 11pt
 
@@ -135,7 +144,15 @@
 host's package manager (`apt install fonts-liberation fonts-noto-cjk` on
 Debian/Ubuntu containers).
 
+
+### Font requirements — steps
+
+> The renderer needs:
+
+- `fonts-liberation` (Helvetica/Arial substitute)
+- `fonts-noto-cjk` (Chinese/Japanese/Korean characters)
 ## Delivery
+use judgment to follow the Delivery guidance:
 
 After rendering, deliver via the agent's preferred channel:
 
@@ -149,7 +166,8 @@
 can also see it on GitHub / locally. The PDF is a rendering; the source
 is the artifact.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ Generating a PDF without first confirming the brain page exists.
   No source = no PDF.
@@ -161,7 +179,10 @@
 - ❌ Using raw `MEDIA:` tags for Telegram delivery. Use the `message`
   tool with `filePath`.
 
-## Related skills
+## Related skills (( inert, role: procedure ))
+
+
+### Related skills — steps
 
 - `skills/book-mirror/SKILL.md` — produces a brain page that's a
   natural input to brain-pdf (chapter-by-chapter personalized analysis).
@@ -170,7 +191,8 @@
   HTML (different rendering target).
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -181,7 +203,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
