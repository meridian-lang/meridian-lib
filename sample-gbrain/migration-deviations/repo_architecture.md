# Deviation: repo_architecture.meri

- Original: `repo-architecture/SKILL.md`
- Ported: `repo_architecture.meri`
- Tier: 2 (light edits)
- Similarity: 63%
- Lines: 54 -> 50 (+17 / -21)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 1/4 inert (25% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 1 blocks, 4 lines

### Inert section details
- L22 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/repo-architecture/SKILL.md
+++ skills/repo_architecture.meri
@@ -20,35 +20,31 @@
 
 > **Full filing rules:** See `skills/_brain-filing-rules.md`
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- Every new page is filed by primary subject (not format, not source)
-- The decision protocol is followed for ambiguous cases
-- Common misfiling patterns are caught
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Every new page is filed by primary subject (not format, not source)
+- [ ] The decision protocol is followed for ambiguous cases
+- [ ] Common misfiling patterns are caught
 
 ## Phases
 
-1. **Identify the primary subject.** What would you search for to find this page?
-2. **Walk the decision tree:**
-   - About a person → `people/{name-slug}.md`
-   - About a company → `companies/{name-slug}.md`
-   - A reusable concept/framework → `concepts/{slug}.md`
-   - An original idea → `originals/{slug}.md`
-   - A meeting → `meetings/{slug}.md`
-   - Media content → `media/{type}/{slug}.md`
-   - Raw data import → `sources/{slug}.md`
-3. **Cross-link.** Link from related directories.
-4. **Check notability.** See `skills/conventions/quality.md` notability gate.
+use judgment to file a new brain page by its primary subject:
+  Identify the primary subject (what you would search for to find this page).
+  Walk the decision tree: a person to people/, a company to companies/, a reusable concept to concepts/, an original idea to originals/, a meeting to meetings/, media to media/, and a raw data import to sources/.
+  Cross-link from related directories.
+  Check the notability gate before creating the page.
 
 ## Output Format
 
 Advisory: "File this at `{type}/{slug}.md` because the primary subject is {reason}."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Filing by format ("it's a PDF so it goes in sources/")
-- Filing by source ("it came from email so it goes in sources/")
-- Creating pages without checking if one already exists
-- Using `sources/` for anything except raw data dumps
+!!! checklist (( ai-autonomy ))
+- [ ] Filing by format ("it's a PDF so it goes in sources/")
+- [ ] Filing by source ("it came from email so it goes in sources/")
+- [ ] Creating pages without checking if one already exists
+- [ ] Using `sources/` for anything except raw data dumps
 
```
