# Deviation: signal_detector.meri

- Original: `signal-detector/SKILL.md`
- Ported: `signal_detector.meri`
- Tier: 1 (near-verbatim)
- Similarity: 88%
- Lines: 113 -> 113 (+13 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- command-hole-rewritten
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L13 `Contract`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L32 `Phases`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L34 `Phase 1: Idea/Observation Detection (PRIMARY)`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L46 `Phase 2: Entity Detection (SECONDARY)`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L61 `Phase 3: Signal Logging`: operational-procedure - Marked or derived as procedure, but inert suppresses execution.
- L69 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L74 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L82 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections: 8/8 inert (100% inert ratio)
- Operational inert: 4
- Unclassified inert: 0
- Inert categories: operational-procedure=4, reference-documentation=2, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L13 `Contract`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L32 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L34 `Phase 1: Idea/Observation Detection (PRIMARY)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L46 `Phase 2: Entity Detection (SECONDARY)`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L61 `Phase 3: Signal Logging`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L69 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L74 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L82 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

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
@@ -52,9 +52,9 @@
 3. Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
 4. An unlinked mention is a broken brain.
 
-## Phases
+## Phases (( inert, role: procedure ))
 
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
@@ -89,12 +89,12 @@
 
 This makes the ambient capture loop debuggable.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 No visible output to the user. This skill runs silently in the background.
 The output is brain pages created/updated and the signal log line.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Blocking the main response to wait for signal detection to complete
 - Paraphrasing the user's original thinking instead of capturing exact phrasing
```
