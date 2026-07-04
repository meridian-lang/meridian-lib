# Deviation: repo_architecture.meri

- Original: `repo-architecture/SKILL.md`
- Ported: `repo_architecture.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 54 -> 54 (+4 / -4)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L6 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L13 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L27 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L31 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.

## Metrics
- Sections: 4/4 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L6 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L13 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L27 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L31 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/repo-architecture/SKILL.md
+++ skills/repo_architecture.meri
@@ -20,14 +20,14 @@
 
 > **Full filing rules:** See `skills/_brain-filing-rules.md`
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every new page is filed by primary subject (not format, not source)
 - The decision protocol is followed for ambiguous cases
 - Common misfiling patterns are caught
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Identify the primary subject.** What would you search for to find this page?
 2. **Walk the decision tree:**
@@ -41,11 +41,11 @@
 3. **Cross-link.** Link from related directories.
 4. **Check notability.** See `skills/conventions/quality.md` notability gate.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Advisory: "File this at `{type}/{slug}.md` because the primary subject is {reason}."
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Filing by format ("it's a PDF so it goes in sources/")
 - Filing by source ("it came from email so it goes in sources/")
```
