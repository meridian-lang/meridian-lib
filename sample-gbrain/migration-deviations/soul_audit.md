# Deviation: soul_audit.meri

- Original: `soul-audit/SKILL.md`
- Ported: `soul_audit.meri`
- Tier: 2 (light edits)
- Similarity: 85%
- Lines: 86 -> 86 (+13 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 10/11 inert (91% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/soul-audit/SKILL.md
+++ soul_audit.meri
@@ -18,13 +18,13 @@
 
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
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - SOUL.md generated from user's description of agent identity, vibe, mission
@@ -36,11 +36,11 @@
 
 ## Phases
 
-### Phase 1: Identity Interview
+### Phase 1: Identity Interview (( inert, role: procedure ))
 Ask: "What is this agent to you? Research partner? Executive assistant? Thinking partner? All of the above?"
 Generate: SOUL.md identity section.
 
-### Phase 2: Vibe Calibration
+### Phase 2: Vibe Calibration (( inert, role: procedure ))
 Show 3-4 communication style examples:
 - **Formal:** "I've prepared a comprehensive analysis of the situation..."
 - **Direct:** "Here's what's happening. Three things matter."
@@ -48,23 +48,23 @@
 - **Casual:** "Yeah so basically the thing is broken because X. Easy fix."
 Ask which feels right. Generate: SOUL.md vibe + communication style sections.
 
-### Phase 3: Mission Mapping
+### Phase 3: Mission Mapping (( inert, role: procedure ))
 Ask: "What are your top 3-5 goals? What are you trying to accomplish?"
 Generate: SOUL.md mission + operating principles sections.
 
-### Phase 4: User Profile
+### Phase 4: User Profile (( inert, role: procedure ))
 Ask: "Tell me about yourself. What do you do? What are you working on? Who are the key people in your world?"
 Generate: USER.md with role, projects, key people, communication preferences.
 
-### Phase 5: Boundaries
+### Phase 5: Boundaries (( inert, role: procedure ))
 Ask: "Who should have access to your brain? Are there people who should see some but not all? Anyone to keep out entirely?"
 Generate: ACCESS_POLICY.md with 4 tiers (Full/Work/Family/None).
 
-### Phase 6: Operational Cadence
+### Phase 6: Operational Cadence (( inert, role: procedure ))
 Ask: "How often should the agent check in? Morning briefing? End of day summary? What recurring jobs do you want?"
 Generate: HEARTBEAT.md with operational cadence.
 
-## Default Mode (Skip Soul-Audit)
+## Default Mode (Skip Soul-Audit) (( inert ))
 
 If the user skips soul-audit on first boot:
 - Install `templates/SOUL.md.template` as SOUL.md (minimal: "knowledge-first agent with persistent memory")
@@ -77,7 +77,7 @@
 Four files generated/updated. Report: "Soul audit complete: SOUL.md, USER.md,
 ACCESS_POLICY.md, HEARTBEAT.md created. Re-run any phase anytime to update."
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Shipping pre-filled SOUL.md or USER.md content (privacy violation)
 - Making soul-audit mandatory on first boot (high friction, optional is better)
```
