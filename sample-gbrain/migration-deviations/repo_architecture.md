# Deviation: repo_architecture.meri

- Original: `repo-architecture/SKILL.md`
- Ported: `repo_architecture.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 54 -> 57 (+6 / -3)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L29 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L29 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/repo-architecture/SKILL.md
+++ skills/repo_architecture.meri
@@ -20,7 +20,8 @@
 
 > **Full filing rules:** See `skills/_brain-filing-rules.md`
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Every new page is filed by primary subject (not format, not source)
@@ -28,6 +29,7 @@
 - Common misfiling patterns are caught
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 1. **Identify the primary subject.** What would you search for to find this page?
 2. **Walk the decision tree:**
@@ -41,11 +43,12 @@
 3. **Cross-link.** Link from related directories.
 4. **Check notability.** See `skills/conventions/quality.md` notability gate.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Advisory: "File this at `{type}/{slug}.md` because the primary subject is {reason}."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Filing by format ("it's a PDF so it goes in sources/")
 - Filing by source ("it came from email so it goes in sources/")
```
