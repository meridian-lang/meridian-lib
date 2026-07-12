# Deviation: skill_creator.meri

- Original: `skill-creator/SKILL.md`
- Ported: `skill_creator.meri`
- Tier: 2 (light edits)
- Similarity: 83%
- Lines: 83 -> 92 (+19 / -10)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L65 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L69 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- generated_loc: 52 non-blank ported lines
- Sections inert total: 4/4 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=1, structure=0, desugar=0, meaning=55

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L16 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L65 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L69 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/skill-creator/SKILL.md
+++ skills/skill_creator.meri
@@ -17,18 +17,20 @@
 
 # Skill Creator
 
-## Contract
+## Contract (( role: reference ))
 
-This skill guarantees:
-- New skill follows conformance standard (frontmatter + required sections)
 - MECE check: no overlap with existing skills' triggers
 - Manifest.json updated
 - RESOLVER.md updated with routing entry
 - Skill passes conformance tests (`bun test test/skills-conformance.test.ts`)
 
-## Phases
 
-1. **Identify the gap.** What capability is missing? What user intent has no skill?
+### Contract — steps (( role: reference ))
+
+> This skill guarantees:
+- New skill follows conformance standard (frontmatter + required sections)
+## Phases (( role: reference ))
+
 2. **MECE check.** Review `skills/manifest.json` and `skills/RESOLVER.md`. Does any existing skill already cover this? If so, extend it instead of creating a new one.
 3. **Create SKILL.md.** Use this template:
 
@@ -65,15 +67,22 @@
 {GBrain operations used, with descriptions}
 ```
 
-4. **Add to manifest.** Update `skills/manifest.json` with name, path, description.
-5. **Add to resolver.** Update `skills/RESOLVER.md` with routing entry in the appropriate category.
-6. **Verify.** Run `bun test test/skills-conformance.test.ts` to confirm the new skill passes.
 
-## Output Format
+### Phases — steps (( role: reference ))
+
+1. What capability is missing? What user intent has no skill?
+
+### Phases — steps 2
+
+4. Add to manifest. Update `skills/manifest.json` with name, path, description.
+5. Add to resolver. Update `skills/RESOLVER.md` with routing entry in the appropriate category.
+6. Verify. Run `bun test test/skills-conformance.test.ts` to confirm the new skill passes.
+
+## Output Format (( role: template ))
 
 New `skills/{name}/SKILL.md` file + updated manifest + updated resolver.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Creating a skill that overlaps with an existing one (violates MECE)
 - Skipping the MECE check against existing skills
```
