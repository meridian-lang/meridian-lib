# Deviation: signal_detector.meri

- Original: `signal-detector/SKILL.md`
- Ported: `signal_detector.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 113 -> 128 (+30 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- command-hole-rewritten
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L83 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L97 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 2/8 (25% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1, tools-metadata=1
- Judgment: 6 blocks, 0 lines

### Inert section details
- L83 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L97 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/signal-detector/SKILL.md
+++ skills/signal_detector.meri
@@ -24,16 +24,17 @@
 
 # Signal Detector — Ambient Brain Capture
 
-Lightweight sub-agent that fires on every inbound message to capture TWO things
-with EQUAL priority:
+> Lightweight sub-agent that fires on every inbound message to capture TWO things
+> with EQUAL priority:
 
-1. **Original thinking** — the user's ideas, observations, theses, frameworks
-2. **Entity mentions** — people, companies, media references
+> 1. **Original thinking** — the user's ideas, observations, theses, frameworks
+> 2. **Entity mentions** — people, companies, media references
 
-Original thinking is AT LEAST as valuable as entity extraction. Ideas are the
-intellectual capital. Entities are bookkeeping. Both compound over time.
+> Original thinking is AT LEAST as valuable as entity extraction. Ideas are the
+> intellectual capital. Entities are bookkeeping. Both compound over time.
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - Fires on every message (no exceptions unless purely operational)
@@ -53,8 +54,10 @@
 4. An unlinked mention is a broken brain.
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 ### Phase 1: Idea/Observation Detection (PRIMARY)
+use judgment to follow the Phase 1: Idea/Observation Detection (PRIMARY) guidance:
 
 When the user expresses a novel thought, observation, thesis, or framework:
 - If it's the user's **original thinking** (they generated it) → create/update `originals/{slug}`
@@ -67,34 +70,46 @@
 meetings, and concepts. An original without cross-links is a dead original.
 
 ### Phase 2: Entity Detection (SECONDARY)
+use judgment to follow the Phase 2: Entity Detection (SECONDARY) guidance:
 
 1. Extract entity mentions (people, companies, media titles)
-2. For each entity:
-   - `gbrain search "name"` — does a page exist?
    - If NO page → check notability. If notable, create page with enrichment.
    - If page exists but THIN → trigger enrich
    - If page exists and RICH → no action
-3. For new FACTS with specific dates → call `gbrain timeline-add <slug> <date> "<summary>"`
-
 **Auto-link (v0.10.1):** When you write/update an originals or ideas page that
 references a person or company, the auto-link post-hook on `put_page`
 automatically creates the link from the new page to that entity. You don't
 need to call `gbrain link` manually. Timeline entries still need explicit calls.
 
+
+#### Phase 2: Entity Detection (SECONDARY) — steps
+
+2. For each entity:
+   - `gbrain search "name"` — does a page exist?
+
+#### Phase 2: Entity Detection (SECONDARY) — steps 2
+
+3. For new FACTS with specific dates → call `gbrain timeline-add <slug> <date> "<summary>"`
+
 ### Phase 3: Signal Logging
+use judgment to follow the Phase 3: Signal Logging guidance:
 
 Always log a one-line summary:
+This makes the ambient capture loop debuggable.
+
+
+#### Phase 3: Signal Logging — steps
+
 - `Signals: 0 ideas, 0 entities, 0 facts (skipped: operational)`
 - `Signals: 1 idea (captured → originals/x), 2 entities (enriched → people/y, companies/z)`
 
-This makes the ambient capture loop debuggable.
-
-## Output Format
+## Output Format (( inert, role: template ))
 
 No visible output to the user. This skill runs silently in the background.
 The output is brain pages created/updated and the signal log line.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Blocking the main response to wait for signal detection to complete
 - Paraphrasing the user's original thinking instead of capturing exact phrasing
```
