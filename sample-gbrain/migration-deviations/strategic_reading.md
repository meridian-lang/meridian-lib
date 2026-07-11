# Deviation: strategic_reading.meri

- Original: `strategic-reading/SKILL.md`
- Ported: `strategic_reading.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 189 -> 209 (+44 / -24)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L46 `Output`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L50 `Brain page structure`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L169 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L180 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L184 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 9/10 (90% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=7, template=2
- Judgment: 2 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=147

### Inert section details
- L12 `What this is`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Inputs`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L50 `Brain page structure`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L129 `Quality bar`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L145 `What this skill is NOT`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L169 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L180 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L184 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/strategic-reading/SKILL.md
+++ skills/strategic_reading.meri
@@ -31,34 +31,45 @@
 > output files by primary subject (concepts/ for general strategy, projects/
 > for problem-tied playbooks).
 
-## What this is
-
-Take a large text PLUS a specific strategic problem, produce analysis that
-maps the text's insights onto the problem. This is not book summarization.
+## What this is (( role: reference ))
+
 This is reading with a mission.
-
-Where `book-mirror` personalizes a book to the reader's whole life,
-`strategic-reading` personalizes it to ONE current problem. Same shape
-(extract → analyze → mirror), different lens.
 
 **Canonical example:** a power-dynamics history book read against a
 specific gatekeeper-vs-incumbent fight, producing a tactical analysis that
 maps the book's playbook onto the situation with counter-tactics and a
 short/medium/long-term playbook.
 
-## Inputs
+
+### What this is — steps (( role: reference ))
+
+Take a large text PLUS a specific strategic problem, produce analysis that
+maps the text's insights onto the problem. This is not book summarization.
+
+### What this is — steps 2
+
+use judgment to follow the What this is — steps 2 guidance:
+Where `book-mirror` personalizes a book to the reader's whole life,
+`strategic-reading` personalizes it to ONE current problem. Same shape
+(extract → analyze → mirror), different lens.
+
+## Inputs (( role: reference ))
 
 1. **Source text** — book (EPUB/PDF), article, transcript, historical case
    study, any large document.
+
+### Inputs — steps
+
+use judgment to follow the Inputs — steps guidance:
 2. **Strategic problem** — the specific situation to analyze through the
    lens of the text. The user describes this explicitly or it's obvious
    from context.
 
-## Output
+## Output (( role: template ))
 
 The brain page is the artifact. PDF is a rendering, never primary.
 
-### Brain page structure
+### Brain page structure (( role: reference ))
 
 ```markdown
 # [Source Title] — Applied to [Problem]
@@ -137,12 +148,8 @@
   └── Optional: render to PDF via skills/brain-pdf.
 ```
 
-## Quality bar
-
-- **Every recommendation must cite the source.** Don't say "go direct to
-  the mayor" — say "go direct to the mayor, because when the protagonist
-  refused to be intimidated by a resignation threat (Ch 48), the bluff
-  that worked on five mayors finally failed."
+## Quality bar (( role: reference ))
+
 - **Direct quotes are mandatory.** The source's own words carry more
   weight than paraphrase.
 - **The analysis must be actionable.** Not "this is interesting" but "do
@@ -150,16 +157,29 @@
 - **Short/medium/long-term breakdown is mandatory.** The user needs to
   know what to do tomorrow AND what to do this year.
 
-## What this skill is NOT
+
+### Quality bar — steps
+
+- Don't say "go direct to
+  the mayor" — say "go direct to the mayor, because when the protagonist
+  refused to be intimidated by a resignation threat (Ch 48), the bluff
+  that worked on five mayors finally failed."
+## What this skill is NOT (( role: reference ))
+
+- Not academic literary analysis. No one cares about literary merit —
+  only strategic application.
+
+
+### What this skill is NOT — steps
 
 - Not a book summary tool. Use a different skill (or `book-mirror` for
   personalized analysis) for general summaries.
 - Not a research tool. Use `perplexity-research` for finding new
   information about a topic.
-- Not academic literary analysis. No one cares about literary merit —
-  only strategic application.
-
 ## Related skills
+
+
+### Related skills — steps
 
 - `skills/book-mirror/SKILL.md` — book personalized to whole life (vs
   problem)
@@ -168,7 +188,7 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -179,11 +199,11 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
 
```
