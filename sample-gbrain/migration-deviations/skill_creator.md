# Deviation: skill_creator.meri

- Original: `skill-creator/SKILL.md`
- Ported: `skill_creator.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 83 -> 83 (+9 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 4/4 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L13 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L56 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L60 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

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
@@ -26,7 +26,7 @@
 - RESOLVER.md updated with routing entry
 - Skill passes conformance tests (`bun test test/skills-conformance.test.ts`)
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Identify the gap.** What capability is missing? What user intent has no skill?
 2. **MECE check.** Review `skills/manifest.json` and `skills/RESOLVER.md`. Does any existing skill already cover this? If so, extend it instead of creating a new one.
@@ -49,19 +49,19 @@
 
 # {Skill Title}
 
-## Contract
+## Contract (( inert, role: invariants ))
 {What this skill guarantees — 3-5 bullet points}
 
-## Phases
+## Phases (( inert, role: procedure ))
 {Numbered workflow steps}
 
-## Output Format
+## Output Format (( inert, role: template ))
 {What good output looks like}
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 {What NOT to do — 3-5 items}
 
-## Tools Used
+## Tools Used (( inert, role: tools ))
 {GBrain operations used, with descriptions}
 ```
 
@@ -69,11 +69,11 @@
 5. **Add to resolver.** Update `skills/RESOLVER.md` with routing entry in the appropriate category.
 6. **Verify.** Run `bun test test/skills-conformance.test.ts` to confirm the new skill passes.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 New `skills/{name}/SKILL.md` file + updated manifest + updated resolver.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Creating a skill that overlaps with an existing one (violates MECE)
 - Skipping the MECE check against existing skills
```
