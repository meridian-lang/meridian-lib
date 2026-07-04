# Deviation: soul_audit.meri

- Original: `soul-audit/SKILL.md`
- Ported: `soul_audit.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 86 -> 98 (+21 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L69 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/10 (10% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1
- Judgment: 9 blocks, 0 lines

### Inert section details
- L69 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/soul-audit/SKILL.md
+++ skills/soul_audit.meri
@@ -18,13 +18,14 @@
 
 # Soul Audit — Agent Identity Builder
 
-Generate the agent's identity and operational configuration through an interactive
-interview. Each phase produces a file. Any phase can be re-run independently to update.
+> Generate the agent's identity and operational configuration through an interactive
+> interview. Each phase produces a file. Any phase can be re-run independently to update.
 
-**IMPORTANT:** This skill generates content from the USER'S OWN ANSWERS. It NEVER
-ships pre-filled content. The templates in `templates/` are scaffolds, not defaults.
+> **IMPORTANT:** This skill generates content from the USER'S OWN ANSWERS. It NEVER
+> ships pre-filled content. The templates in `templates/` are scaffolds, not defaults.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - SOUL.md generated from user's description of agent identity, vibe, mission
@@ -35,12 +36,15 @@
 - Default mode (skip soul-audit): installs minimal templates from `templates/`
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 ### Phase 1: Identity Interview
+use judgment to follow the Phase 1: Identity Interview guidance:
 Ask: "What is this agent to you? Research partner? Executive assistant? Thinking partner? All of the above?"
 Generate: SOUL.md identity section.
 
 ### Phase 2: Vibe Calibration
+use judgment to follow the Phase 2: Vibe Calibration guidance:
 Show 3-4 communication style examples:
 - **Formal:** "I've prepared a comprehensive analysis of the situation..."
 - **Direct:** "Here's what's happening. Three things matter."
@@ -49,35 +53,43 @@
 Ask which feels right. Generate: SOUL.md vibe + communication style sections.
 
 ### Phase 3: Mission Mapping
+use judgment to follow the Phase 3: Mission Mapping guidance:
 Ask: "What are your top 3-5 goals? What are you trying to accomplish?"
 Generate: SOUL.md mission + operating principles sections.
 
 ### Phase 4: User Profile
+use judgment to follow the Phase 4: User Profile guidance:
 Ask: "Tell me about yourself. What do you do? What are you working on? Who are the key people in your world?"
 Generate: USER.md with role, projects, key people, communication preferences.
 
 ### Phase 5: Boundaries
+use judgment to follow the Phase 5: Boundaries guidance:
 Ask: "Who should have access to your brain? Are there people who should see some but not all? Anyone to keep out entirely?"
 Generate: ACCESS_POLICY.md with 4 tiers (Full/Work/Family/None).
 
 ### Phase 6: Operational Cadence
+use judgment to follow the Phase 6: Operational Cadence guidance:
 Ask: "How often should the agent check in? Morning briefing? End of day summary? What recurring jobs do you want?"
 Generate: HEARTBEAT.md with operational cadence.
 
-## Default Mode (Skip Soul-Audit)
+## Default Mode (Skip Soul-Audit) (( inert ))
 
-If the user skips soul-audit on first boot:
+
+### Default Mode (Skip Soul-Audit) — steps
+
+> If the user skips soul-audit on first boot:
 - Install `templates/SOUL.md.template` as SOUL.md (minimal: "knowledge-first agent with persistent memory")
 - Install `templates/USER.md.template` as USER.md (auto-populate name/email from git config)
 - Install `templates/ACCESS_POLICY.md.template` as ACCESS_POLICY.md (owner-only access)
 - Install `templates/HEARTBEAT.md.template` as HEARTBEAT.md (default cadence)
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Four files generated/updated. Report: "Soul audit complete: SOUL.md, USER.md,
 ACCESS_POLICY.md, HEARTBEAT.md created. Re-run any phase anytime to update."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Shipping pre-filled SOUL.md or USER.md content (privacy violation)
 - Making soul-audit mandatory on first boot (high friction, optional is better)
```
