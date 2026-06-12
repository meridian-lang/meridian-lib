# Deviation: signal_detector.meri

- Original: `signal-detector/SKILL.md`
- Ported: `signal_detector.meri`
- Tier: 1 (near-verbatim)
- Similarity: 89%
- Lines: 113 -> 113 (+12 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- command-hole-rewritten

## Metrics
- Sections: 7/8 inert (88% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/signal-detector/SKILL.md
+++ skills/signal_detector.meri
@@ -24,16 +24,16 @@
 
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
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - Fires on every message (no exceptions unless purely operational)
@@ -54,7 +54,7 @@
 
 ## Phases
 
-### Phase 1: Idea/Observation Detection (PRIMARY)
+### Phase 1: Idea/Observation Detection (PRIMARY) (( inert, role: procedure ))
 
 When the user expresses a novel thought, observation, thesis, or framework:
 - If it's the user's **original thinking** (they generated it) → create/update `originals/{slug}`
@@ -66,7 +66,7 @@
 **Cross-linking (MANDATORY):** Every original MUST link to related people, companies,
 meetings, and concepts. An original without cross-links is a dead original.
 
-### Phase 2: Entity Detection (SECONDARY)
+### Phase 2: Entity Detection (SECONDARY) (( inert, role: procedure ))
 
 1. Extract entity mentions (people, companies, media titles)
 2. For each entity:
@@ -81,7 +81,7 @@
 automatically creates the link from the new page to that entity. You don't
 need to call `gbrain link` manually. Timeline entries still need explicit calls.
 
-### Phase 3: Signal Logging
+### Phase 3: Signal Logging (( inert, role: procedure ))
 
 Always log a one-line summary:
 - `Signals: 0 ideas, 0 entities, 0 facts (skipped: operational)`
@@ -94,7 +94,7 @@
 No visible output to the user. This skill runs silently in the background.
 The output is brain pages created/updated and the signal log line.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Blocking the main response to wait for signal detection to complete
 - Paraphrasing the user's original thinking instead of capturing exact phrasing
@@ -102,7 +102,7 @@
 - Skipping back-links after creating/updating pages
 - Running on purely operational messages ("ok", "thanks", "do it")
 
-## Tools Used
+## Tools Used (( inert ))
 
 - `search` — check if entity page exists
 - `query` — semantic search for related context
```
