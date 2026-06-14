# Deviation: soul_audit.meri

- Original: `soul-audit/SKILL.md`
- Ported: `soul_audit.meri`
- Tier: 3 (structural rewrite)
- Similarity: 46%
- Lines: 86 -> 94 (+53 / -45)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted

## Metrics
- Sections: 2/11 inert (18% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 6 blocks, 16 lines

### Inert section details
- L57 `Default Mode (Skip Soul-Audit)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L65 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/soul-audit/SKILL.md
+++ skills/soul_audit.meri
@@ -18,53 +18,60 @@
 
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
 
-This skill guarantees:
-- SOUL.md generated from user's description of agent identity, vibe, mission
-- USER.md generated from user's self-description (role, projects, key people)
-- ACCESS_POLICY.md generated with configurable access tiers
-- HEARTBEAT.md generated with operational cadence the user chooses
-- Each phase is independent and re-runnable
-- Default mode (skip soul-audit): installs minimal templates from `templates/`
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] SOUL.md generated from user's description of agent identity, vibe, mission
+- [ ] USER.md generated from user's self-description (role, projects, key people)
+- [ ] ACCESS_POLICY.md generated with configurable access tiers
+- [ ] HEARTBEAT.md generated with operational cadence the user chooses
+- [ ] Each phase is independent and re-runnable
+- [ ] Default mode (skip soul-audit): installs minimal templates from `templates/`
 
 ## Phases
 
-### Phase 1: Identity Interview
-Ask: "What is this agent to you? Research partner? Executive assistant? Thinking partner? All of the above?"
-Generate: SOUL.md identity section.
+### Phase 1: Identity Interview (( role: procedure ))
 
-### Phase 2: Vibe Calibration
-Show 3-4 communication style examples:
-- **Formal:** "I've prepared a comprehensive analysis of the situation..."
-- **Direct:** "Here's what's happening. Three things matter."
-- **Technical:** "The root cause is in the connection pooling. Here's the fix."
-- **Casual:** "Yeah so basically the thing is broken because X. Easy fix."
-Ask which feels right. Generate: SOUL.md vibe + communication style sections.
-
-### Phase 3: Mission Mapping
-Ask: "What are your top 3-5 goals? What are you trying to accomplish?"
-Generate: SOUL.md mission + operating principles sections.
-
-### Phase 4: User Profile
-Ask: "Tell me about yourself. What do you do? What are you working on? Who are the key people in your world?"
-Generate: USER.md with role, projects, key people, communication preferences.
-
-### Phase 5: Boundaries
-Ask: "Who should have access to your brain? Are there people who should see some but not all? Anyone to keep out entirely?"
-Generate: ACCESS_POLICY.md with 4 tiers (Full/Work/Family/None).
-
-### Phase 6: Operational Cadence
-Ask: "How often should the agent check in? Morning briefing? End of day summary? What recurring jobs do you want?"
-Generate: HEARTBEAT.md with operational cadence.
-
-## Default Mode (Skip Soul-Audit)
+use judgment to follow the Phase 1: Identity Interview guidance:
+  Ask: "What is this agent to you? Research partner? Executive assistant? Thinking partner? All of the above?"
+  Generate: SOUL.md identity section.
+### Phase 2: Vibe Calibration (( role: procedure ))
+  
+use judgment to follow the Phase 2: Vibe Calibration guidance:
+  Show 3-4 communication style examples:
+  item: **Formal:** "I've prepared a comprehensive analysis of the situation..."
+  item: **Direct:** "Here's what's happening. Three things matter."
+  item: **Technical:** "The root cause is in the connection pooling. Here's the fix."
+  item: **Casual:** "Yeah so basically the thing is broken because X. Easy fix."
+  Ask which feels right. Generate: SOUL.md vibe + communication style sections.
+### Phase 3: Mission Mapping (( role: procedure ))
+  
+use judgment to follow the Phase 3: Mission Mapping guidance:
+  Ask: "What are your top 3-5 goals? What are you trying to accomplish?"
+  Generate: SOUL.md mission + operating principles sections.
+### Phase 4: User Profile (( role: procedure ))
+  
+use judgment to follow the Phase 4: User Profile guidance:
+  Ask: "Tell me about yourself. What do you do? What are you working on? Who are the key people in your world?"
+  Generate: USER.md with role, projects, key people, communication preferences.
+### Phase 5: Boundaries (( role: procedure ))
+  
+use judgment to follow the Phase 5: Boundaries guidance:
+  Ask: "Who should have access to your brain? Are there people who should see some but not all? Anyone to keep out entirely?"
+  Generate: ACCESS_POLICY.md with 4 tiers (Full/Work/Family/None).
+### Phase 6: Operational Cadence (( role: procedure ))
+  
+use judgment to follow the Phase 6: Operational Cadence guidance:
+  Ask: "How often should the agent check in? Morning briefing? End of day summary? What recurring jobs do you want?"
+  Generate: HEARTBEAT.md with operational cadence.
+## Default Mode (Skip Soul-Audit) (( inert ))
 
 If the user skips soul-audit on first boot:
 - Install `templates/SOUL.md.template` as SOUL.md (minimal: "knowledge-first agent with persistent memory")
@@ -77,10 +84,11 @@
 Four files generated/updated. Report: "Soul audit complete: SOUL.md, USER.md,
 ACCESS_POLICY.md, HEARTBEAT.md created. Re-run any phase anytime to update."
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Shipping pre-filled SOUL.md or USER.md content (privacy violation)
-- Making soul-audit mandatory on first boot (high friction, optional is better)
-- Asking all 6 phases in one go (overwhelming, each is independent)
-- Not offering to re-run individual phases
+!!! checklist (( ai-autonomy ))
+- [ ] Shipping pre-filled SOUL.md or USER.md content (privacy violation)
+- [ ] Making soul-audit mandatory on first boot (high friction, optional is better)
+- [ ] Asking all 6 phases in one go (overwhelming, each is independent)
+- [ ] Not offering to re-run individual phases
 
```
