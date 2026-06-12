# Deviation: skill_creator.meri

- Original: `skill-creator/SKILL.md`
- Ported: `skill_creator.meri`
- Tier: 2 (light edits)
- Similarity: 64%
- Lines: 83 -> 52 (+9 / -40)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Unified diff

```diff
--- original-skills/skill-creator/SKILL.md
+++ skills/skill_creator.meri
@@ -17,7 +17,7 @@
 
 # Skill Creator
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - New skill follows conformance standard (frontmatter + required sections)
@@ -28,52 +28,21 @@
 
 ## Phases
 
-1. **Identify the gap.** What capability is missing? What user intent has no skill?
-2. **MECE check.** Review `skills/manifest.json` and `skills/RESOLVER.md`. Does any existing skill already cover this? If so, extend it instead of creating a new one.
-3. **Create SKILL.md.** Use this template:
+use judgment to create a new skill:
+  Identify the missing capability or user intent that has no skill.
+  Run a MECE check against the manifest and resolver, extending an existing skill rather than duplicating coverage.
+  Create the SKILL.md from the standard template with frontmatter, Contract, Phases, Output Format, and Anti-Patterns.
+  Add the skill to the manifest and to the resolver routing table.
 
-```yaml
----
-name: {skill-name}
-version: 1.0.0
-description: |
-  {One paragraph describing what the skill does and when to use it.}
-triggers:
-  - "{trigger phrase 1}"
-  - "{trigger phrase 2}"
-tools:
-  - {tool1}
-  - {tool2}
-mutating: {true|false}
----
-
-# {Skill Title}
-
-## Contract
-{What this skill guarantees — 3-5 bullet points}
-
-## Phases
-{Numbered workflow steps}
-
-## Output Format
-{What good output looks like}
-
-## Anti-Patterns
-{What NOT to do — 3-5 items}
-
-## Tools Used
-{GBrain operations used, with descriptions}
+```bash
+bun test test/skills-conformance.test.ts
 ```
-
-4. **Add to manifest.** Update `skills/manifest.json` with name, path, description.
-5. **Add to resolver.** Update `skills/RESOLVER.md` with routing entry in the appropriate category.
-6. **Verify.** Run `bun test test/skills-conformance.test.ts` to confirm the new skill passes.
 
 ## Output Format
 
 New `skills/{name}/SKILL.md` file + updated manifest + updated resolver.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Creating a skill that overlaps with an existing one (violates MECE)
 - Skipping the MECE check against existing skills
```
