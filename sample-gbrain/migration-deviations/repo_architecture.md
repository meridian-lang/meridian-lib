# Deviation: repo_architecture.meri

- Original: `repo-architecture/SKILL.md`
- Ported: `repo_architecture.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 54 -> 48 (+7 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 3/4 inert (75% inert ratio)
- Judgment: 1 blocks, 4 lines

## Unified diff

```diff
--- original-skills/repo-architecture/SKILL.md
+++ repo_architecture.meri
@@ -20,7 +20,7 @@
 
 > **Full filing rules:** See `skills/_brain-filing-rules.md`
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Every new page is filed by primary subject (not format, not source)
@@ -29,23 +29,17 @@
 
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
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Filing by format ("it's a PDF so it goes in sources/")
 - Filing by source ("it came from email so it goes in sources/")
```
