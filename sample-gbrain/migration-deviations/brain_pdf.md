# Deviation: brain_pdf.meri

- Original: `brain-pdf/SKILL.md`
- Ported: `brain_pdf.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 187 -> 187 (+12 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 12/13 inert (92% inert ratio)
- Operational inert: 4
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-content=2, operational-procedure=1, reference-documentation=7, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L8 `The rule`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L14 `What this does`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L25 `Prerequisite: gstack make-pdf`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L44 `Workflow`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L56 `Invocation`: operational-content — Body contains command, table, checklist, or explicit AI-routing surface.
- L107 `Defaults: NO cover, NO TOC`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L114 `Font requirements`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L127 `Delivery`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L141 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L153 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L162 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L173 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
 
@@ -52,7 +52,7 @@
 [ -x "$P" ] || { echo "make-pdf not installed; install gstack" >&2; exit 1; }
 ```
 
-## Workflow
+## Workflow (( inert, role: procedure ))
 
 ```
 1. RESOLVE  → Confirm the brain page exists (gbrain get <slug>).
@@ -64,7 +64,7 @@
               they fail silently).
 ```
 
-## Invocation
+## Invocation (( inert ))
 
 ```bash
 SLUG="path/to/page"
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
 
@@ -181,7 +181,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
