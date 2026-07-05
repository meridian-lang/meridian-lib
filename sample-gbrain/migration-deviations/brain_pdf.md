# Deviation: brain_pdf.meri

- Original: `brain-pdf/SKILL.md`
- Ported: `brain_pdf.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 187 -> 217 (+57 / -27)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L59 `Workflow`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L125 `Defaults: NO cover, NO TOC`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L168 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L192 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L203 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 9/10 (90% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=8, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L17 `What this does`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L31 `Prerequisite: gstack make-pdf`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L59 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L125 `Defaults: NO cover, NO TOC`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L132 `Font requirements`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L148 `Delivery`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L168 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L192 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L203 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/brain-pdf/SKILL.md
+++ skills/brain_pdf.meri
@@ -18,41 +18,56 @@
 
 ## The rule
 
+
+### The rule — steps (( role: reference ))
+
 The brain page is ALWAYS the source of truth. The PDF is a rendering of
 it, never a standalone artifact. If a PDF exists somewhere, the brain
 page must exist behind it.
 
-## What this does
-
-Renders a brain page (markdown with frontmatter) into a
-publication-quality PDF using the gstack `make-pdf` binary. Output is
-suitable for:
+## What this does (( role: reference ))
 
 - Sharing a personalized book mirror via email or Telegram
 - Delivering a strategic-reading playbook as a clean read
 - Producing a briefing or report with running headers and page numbers
 - Archiving a long-form essay in a portable format
 
-## Prerequisite: gstack make-pdf
-
-This skill depends on the gstack `make-pdf` binary at:
+
+### What this does — steps (( role: reference ))
+
+Renders a brain page (markdown with frontmatter) into a
+publication-quality PDF using the gstack `make-pdf` binary. Output is
+suitable for:
+
+## Prerequisite: gstack make-pdf (( role: reference ))
 
 ```
 $HOME/.claude/skills/gstack/make-pdf/dist/pdf
 ```
 
-The user must have gstack co-installed. If absent, the skill cannot run.
 A future v0.26+ may bundle a fallback PDF renderer; for v0.25.1 gstack
 is a soft prereq.
 
-Verify it exists before invoking:
+
+### Prerequisite: gstack make-pdf — steps
+
+This skill depends on the gstack `make-pdf` binary at:
+
+
+### Prerequisite: gstack make-pdf — steps 2 (( role: reference ))
+
+The user must have gstack co-installed. If absent, the skill cannot run.
+
+### Prerequisite: gstack make-pdf — steps 3
+
+> Verify it exists before invoking:
 
 ```bash
 P="$HOME/.claude/skills/gstack/make-pdf/dist/pdf"
 [ -x "$P" ] || { echo "make-pdf not installed; install gstack" >&2; exit 1; }
 ```
 
-## Workflow
+## Workflow (( role: reference ))
 
 ```
 1. RESOLVE  → Confirm the brain page exists (gbrain get <slug>).
@@ -65,6 +80,9 @@
 ```
 
 ## Invocation
+
+
+### Invocation — steps (( role: reference ))
 
 ```bash
 SLUG="path/to/page"
@@ -115,19 +133,15 @@
 CONTAINER=1 "$P" generate --title "Custom Title" --author "Custom Author" "$CLEAN" "$OUT"
 ```
 
-## Defaults: NO cover, NO TOC
+## Defaults: NO cover, NO TOC (( role: reference ))
 
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
+## Font requirements (( role: reference ))
+
 - Minimum body font size: 10pt (page chrome 9pt)
 - Body text: 11pt
 
@@ -135,21 +149,34 @@
 host's package manager (`apt install fonts-liberation fonts-noto-cjk` on
 Debian/Ubuntu containers).
 
-## Delivery
-
-After rendering, deliver via the agent's preferred channel:
-
-- **Telegram:** use the `message` tool with `filePath="/tmp/<slug>.pdf"`
-  attachment. NEVER use raw `MEDIA:` tags — they fail silently.
+
+### Font requirements — steps
+
+> The renderer needs:
+
+- `fonts-liberation` (Helvetica/Arial substitute)
+- `fonts-noto-cjk` (Chinese/Japanese/Korean characters)
+## Delivery (( role: reference ))
+
 - **Email:** attach via the host's email tool.
 - **Direct file response:** print the PDF path; the user can pull it
   manually.
 
+
+### Delivery — steps (( role: reference ))
+
+> After rendering, deliver via the agent's preferred channel:
+
+- Telegram: use the `message` tool with `filePath="/tmp/<slug>.pdf"`
+  attachment. NEVER use raw `MEDIA:` tags — they fail silently.
+
+### Delivery — steps 2 (( role: reference ))
+
 Always include the brain page link in the delivery message so the user
 can also see it on GitHub / locally. The PDF is a rendering; the source
 is the artifact.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ Generating a PDF without first confirming the brain page exists.
   No source = no PDF.
@@ -163,6 +190,9 @@
 
 ## Related skills
 
+
+### Related skills — steps (( role: reference ))
+
 - `skills/book-mirror/SKILL.md` — produces a brain page that's a
   natural input to brain-pdf (chapter-by-chapter personalized analysis).
 - `skills/strategic-reading/SKILL.md` — same shape, problem-lens variant.
@@ -170,7 +200,7 @@
   HTML (different rendering target).
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -181,7 +211,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
