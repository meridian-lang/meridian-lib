# Deviation: strategic_reading.meri

- Original: `strategic-reading/SKILL.md`
- Ported: `strategic_reading.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 189 -> 201 (+28 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L30 `Inputs`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L38 `Output`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L42 `Brain page structure`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L122 `Quality bar`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L171 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 7/10 (70% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=5, template=2
- Judgment: 3 blocks, 0 lines

### Inert section details
- L12 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L30 `Inputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L38 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L42 `Brain page structure`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L122 `Quality bar`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L135 `What this skill is NOT`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L171 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/strategic-reading/SKILL.md
+++ skills/strategic_reading.meri
@@ -31,10 +31,8 @@
 > output files by primary subject (concepts/ for general strategy, projects/
 > for problem-tied playbooks).
 
-## What this is
-
-Take a large text PLUS a specific strategic problem, produce analysis that
-maps the text's insights onto the problem. This is not book summarization.
+## What this is (( inert ))
+
 This is reading with a mission.
 
 Where `book-mirror` personalizes a book to the reader's whole life,
@@ -46,7 +44,12 @@
 maps the book's playbook onto the situation with counter-tactics and a
 short/medium/long-term playbook.
 
-## Inputs
+
+### What this is — steps (( inert ))
+
+Take a large text PLUS a specific strategic problem, produce analysis that
+maps the text's insights onto the problem. This is not book summarization.
+## Inputs (( inert ))
 
 1. **Source text** — book (EPUB/PDF), article, transcript, historical case
    study, any large document.
@@ -54,11 +57,11 @@
    lens of the text. The user describes this explicitly or it's obvious
    from context.
 
-## Output
+## Output (( inert, role: template ))
 
 The brain page is the artifact. PDF is a rendering, never primary.
 
-### Brain page structure
+### Brain page structure (( inert ))
 
 ```markdown
 # [Source Title] — Applied to [Problem]
@@ -103,6 +106,7 @@
 ```
 
 ## Process
+use judgment to follow the Process guidance:
 
 ```
 Phase 1: Ingest the source
@@ -137,7 +141,7 @@
   └── Optional: render to PDF via skills/brain-pdf.
 ```
 
-## Quality bar
+## Quality bar (( inert ))
 
 - **Every recommendation must cite the source.** Don't say "go direct to
   the mayor" — say "go direct to the mayor, because when the protagonist
@@ -150,16 +154,22 @@
 - **Short/medium/long-term breakdown is mandatory.** The user needs to
   know what to do tomorrow AND what to do this year.
 
-## What this skill is NOT
+## What this skill is NOT (( inert ))
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
-## Related skills
+## Related skills (( inert, role: procedure ))
+
+
+### Related skills — steps
 
 - `skills/book-mirror/SKILL.md` — book personalized to whole life (vs
   problem)
@@ -168,7 +178,8 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -179,11 +190,12 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
 
```
