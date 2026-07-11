# Deviation: repo_architecture.meri

- Original: `repo-architecture/SKILL.md`
- Ported: `repo_architecture.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 54 -> 57 (+8 / -5)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L34 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 4/4 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=31

### Inert section details
- L6 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L13 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L34 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/repo-architecture/SKILL.md
+++ skills/repo_architecture.meri
@@ -20,14 +20,14 @@
 
 > **Full filing rules:** See `skills/_brain-filing-rules.md`
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Every new page is filed by primary subject (not format, not source)
 - The decision protocol is followed for ambiguous cases
 - Common misfiling patterns are caught
 
-## Phases
+## Phases (( role: reference ))
 
 1. **Identify the primary subject.** What would you search for to find this page?
 2. **Walk the decision tree:**
@@ -39,13 +39,16 @@
    - Media content → `media/{type}/{slug}.md`
    - Raw data import → `sources/{slug}.md`
 3. **Cross-link.** Link from related directories.
-4. **Check notability.** See `skills/conventions/quality.md` notability gate.
 
-## Output Format
+### Phases — steps
+
+4. Check notability. See `skills/conventions/quality.md` notability gate.
+
+## Output Format (( role: template ))
 
 Advisory: "File this at `{type}/{slug}.md` because the primary subject is {reason}."
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Filing by format ("it's a PDF so it goes in sources/")
 - Filing by source ("it came from email so it goes in sources/")
```
