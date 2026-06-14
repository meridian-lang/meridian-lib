# Deviation: strategic_reading.meri

- Original: `strategic-reading/SKILL.md`
- Ported: `strategic_reading.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 189 -> 190 (+23 / -22)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 8/11 inert (73% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L12 `What this is`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L27 `Inputs`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L35 `Output`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L39 `Brain page structure`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L118 `Quality bar`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L131 `What this skill is NOT`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L140 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L161 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/strategic-reading/SKILL.md
+++ skills/strategic_reading.meri
@@ -31,7 +31,7 @@
 > output files by primary subject (concepts/ for general strategy, projects/
 > for problem-tied playbooks).
 
-## What this is
+## What this is (( inert ))
 
 Take a large text PLUS a specific strategic problem, produce analysis that
 maps the text's insights onto the problem. This is not book summarization.
@@ -46,7 +46,7 @@
 maps the book's playbook onto the situation with counter-tactics and a
 short/medium/long-term playbook.
 
-## Inputs
+## Inputs (( inert ))
 
 1. **Source text** — book (EPUB/PDF), article, transcript, historical case
    study, any large document.
@@ -58,7 +58,7 @@
 
 The brain page is the artifact. PDF is a rendering, never primary.
 
-### Brain page structure
+### Brain page structure (( inert ))
 
 ```markdown
 # [Source Title] — Applied to [Problem]
@@ -66,39 +66,39 @@
 > One-paragraph executive summary: how the source maps to the situation,
 > the key insight, the bottom line.
 
-## The Core Parallel
+## The Core Parallel (( inert ))
 How the source's central dynamic maps onto the user's situation.
 
-## Chapter / Section Triage
+## Chapter / Section Triage (( inert ))
 For each major section of the source:
 - 2-3 sentence summary of what it says
 - Relevance to the problem: HIGH / MEDIUM / LOW
 - One directly applicable quote (if any)
 
-## The Source's Playbook
+## The Source's Playbook (( inert ))
 The author's framework, tactics, or strategies — organized as:
 - What the protagonist DID (tactics)
 - What WORKED and why
 - What FAILED and why
 - What OPPONENTS did that was effective
 
-## Counter-Tactics
+## Counter-Tactics (( inert ))
 Specific moves from the source that map to the user's situation:
 - What to DO (with source evidence)
 - What to AVOID (with source evidence)
 - What to WATCH FOR (warning signs from the source)
 
-## Applied Playbook
+## Applied Playbook (( inert ))
 The synthesis — actionable recommendations:
 - **Short-term** (this week / this month)
 - **Medium-term** (this quarter)
 - **Long-term** (this year+)
 
-## Key Quotes
+## Key Quotes (( inert ))
 Direct quotes from the source that are devastatingly relevant.
 Maximum 5-10. Quality over quantity.
 
-## See Also
+## See Also (( inert ))
 Links to relevant brain pages (related concepts, related projects).
 ```
 
@@ -137,7 +137,7 @@
   └── Optional: render to PDF via skills/brain-pdf.
 ```
 
-## Quality bar
+## Quality bar (( inert ))
 
 - **Every recommendation must cite the source.** Don't say "go direct to
   the mayor" — say "go direct to the mayor, because when the protagonist
@@ -150,7 +150,7 @@
 - **Short/medium/long-term breakdown is mandatory.** The user needs to
   know what to do tomorrow AND what to do this year.
 
-## What this skill is NOT
+## What this skill is NOT (( inert ))
 
 - Not a book summary tool. Use a different skill (or `book-mirror` for
   personalized analysis) for general summaries.
@@ -159,7 +159,7 @@
 - Not academic literary analysis. No one cares about literary merit —
   only strategic application.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/book-mirror/SKILL.md` — book personalized to whole life (vs
   problem)
@@ -168,22 +168,23 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
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
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
+> The full anti-pattern list is in the body sections above; this header exists for the conformance test if the body uses a different casing.
 
```
