# Deviation: skill_creator.meri

- Original: `skill-creator/SKILL.md`
- Ported: `skill_creator.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 83 -> 92 (+16 / -7)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L64 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/4 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L64 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/skill-creator/SKILL.md
+++ skills/skill_creator.meri
@@ -17,7 +17,8 @@
 
 # Skill Creator
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - New skill follows conformance standard (frontmatter + required sections)
@@ -27,8 +28,8 @@
 - Skill passes conformance tests (`bun test test/skills-conformance.test.ts`)
 
 ## Phases
+use judgment to follow the Phases guidance:
 
-1. **Identify the gap.** What capability is missing? What user intent has no skill?
 2. **MECE check.** Review `skills/manifest.json` and `skills/RESOLVER.md`. Does any existing skill already cover this? If so, extend it instead of creating a new one.
 3. **Create SKILL.md.** Use this template:
 
@@ -65,15 +66,23 @@
 {GBrain operations used, with descriptions}
 ```
 
-4. **Add to manifest.** Update `skills/manifest.json` with name, path, description.
-5. **Add to resolver.** Update `skills/RESOLVER.md` with routing entry in the appropriate category.
-6. **Verify.** Run `bun test test/skills-conformance.test.ts` to confirm the new skill passes.
 
-## Output Format
+### Phases — steps
+
+1. What capability is missing? What user intent has no skill?
+
+### Phases — steps 2
+
+4. Add to manifest. Update `skills/manifest.json` with name, path, description.
+5. Add to resolver. Update `skills/RESOLVER.md` with routing entry in the appropriate category.
+6. Verify. Run `bun test test/skills-conformance.test.ts` to confirm the new skill passes.
+
+## Output Format (( inert, role: template ))
 
 New `skills/{name}/SKILL.md` file + updated manifest + updated resolver.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Creating a skill that overlaps with an existing one (violates MECE)
 - Skipping the MECE check against existing skills
```
