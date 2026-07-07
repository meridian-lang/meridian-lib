# Deviation: soul_audit.meri

- Original: `soul-audit/SKILL.md`
- Ported: `soul_audit.meri`
- Tier: 2 (light edits)
- Similarity: 76%
- Lines: 86 -> 92 (+24 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L22 `Phase 1: Identity Interview`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L26 `Phase 2: Vibe Calibration`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Phase 3: Mission Mapping`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Phase 4: User Profile`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Phase 5: Boundaries`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Phase 6: Operational Cadence`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L61 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 9/9 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=8, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L10 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L22 `Phase 1: Identity Interview`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L26 `Phase 2: Vibe Calibration`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L34 `Phase 3: Mission Mapping`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L38 `Phase 4: User Profile`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L42 `Phase 5: Boundaries`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L46 `Phase 6: Operational Cadence`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L61 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L66 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/soul-audit/SKILL.md
+++ skills/soul_audit.meri
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
+## Contract (( role: reference ))
 
 This skill guarantees:
 - SOUL.md generated from user's description of agent identity, vibe, mission
@@ -36,35 +36,38 @@
 
 ## Phases
 
-### Phase 1: Identity Interview
+### Phase 1: Identity Interview (( role: reference ))
 Ask: "What is this agent to you? Research partner? Executive assistant? Thinking partner? All of the above?"
 Generate: SOUL.md identity section.
 
-### Phase 2: Vibe Calibration
+### Phase 2: Vibe Calibration (( role: reference ))
 Show 3-4 communication style examples:
-- **Formal:** "I've prepared a comprehensive analysis of the situation..."
-- **Direct:** "Here's what's happening. Three things matter."
-- **Technical:** "The root cause is in the connection pooling. Here's the fix."
-- **Casual:** "Yeah so basically the thing is broken because X. Easy fix."
+- Formal: "I've prepared a comprehensive analysis of the situation..."
+- Direct: "Here's what's happening. Three things matter."
+- Technical: "The root cause is in the connection pooling. Here's the fix."
+- Casual: "Yeah so basically the thing is broken because X. Easy fix."
 Ask which feels right. Generate: SOUL.md vibe + communication style sections.
 
-### Phase 3: Mission Mapping
+### Phase 3: Mission Mapping (( role: reference ))
 Ask: "What are your top 3-5 goals? What are you trying to accomplish?"
 Generate: SOUL.md mission + operating principles sections.
 
-### Phase 4: User Profile
+### Phase 4: User Profile (( role: reference ))
 Ask: "Tell me about yourself. What do you do? What are you working on? Who are the key people in your world?"
 Generate: USER.md with role, projects, key people, communication preferences.
 
-### Phase 5: Boundaries
+### Phase 5: Boundaries (( role: reference ))
 Ask: "Who should have access to your brain? Are there people who should see some but not all? Anyone to keep out entirely?"
 Generate: ACCESS_POLICY.md with 4 tiers (Full/Work/Family/None).
 
-### Phase 6: Operational Cadence
+### Phase 6: Operational Cadence (( role: reference ))
 Ask: "How often should the agent check in? Morning briefing? End of day summary? What recurring jobs do you want?"
 Generate: HEARTBEAT.md with operational cadence.
 
 ## Default Mode (Skip Soul-Audit)
+
+
+### Default Mode (Skip Soul-Audit) — steps (( role: reference ))
 
 If the user skips soul-audit on first boot:
 - Install `templates/SOUL.md.template` as SOUL.md (minimal: "knowledge-first agent with persistent memory")
@@ -72,15 +75,18 @@
 - Install `templates/ACCESS_POLICY.md.template` as ACCESS_POLICY.md (owner-only access)
 - Install `templates/HEARTBEAT.md.template` as HEARTBEAT.md (default cadence)
 
-## Output Format
+## Output Format (( role: template ))
 
 Four files generated/updated. Report: "Soul audit complete: SOUL.md, USER.md,
 ACCESS_POLICY.md, HEARTBEAT.md created. Re-run any phase anytime to update."
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Shipping pre-filled SOUL.md or USER.md content (privacy violation)
-- Making soul-audit mandatory on first boot (high friction, optional is better)
 - Asking all 6 phases in one go (overwhelming, each is independent)
 - Not offering to re-run individual phases
 
+
+### Anti-Patterns — steps (( role: reference ))
+
+- Making soul-audit mandatory on first boot (high friction, optional is better)
```
