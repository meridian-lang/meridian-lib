# Deviation: signal_detector.meri

- Original: `signal-detector/SKILL.md`
- Ported: `signal_detector.meri`
- Tier: 2 (light edits)
- Similarity: 72%
- Lines: 113 -> 134 (+45 / -24)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- command-hole-rewritten
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L90 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L95 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L103 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- generated_loc: 71 non-blank ported lines
- Sections inert total: 7/7 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=5, template=1, tools-metadata=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=87

### Inert section details
- L13 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L40 `Phase 1: Idea/Observation Detection (PRIMARY)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L58 `Phase 2: Entity Detection (SECONDARY)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L79 `Phase 3: Signal Logging`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L90 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L95 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L103 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/signal-detector/SKILL.md
+++ skills/signal_detector.meri
@@ -24,20 +24,19 @@
 
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
+## Contract (( role: reference ))
 
 This skill guarantees:
 - Fires on every message (no exceptions unless purely operational)
-- Runs in parallel (spawned, never blocks main response)
 - Captures ideas with the user's EXACT phrasing (no paraphrasing)
 - Detects entity mentions and creates/enriches brain pages
 - Logs a one-line summary of what was captured
@@ -46,55 +45,77 @@
 
 > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
-Every time this skill creates or updates a brain page that mentions a person or company:
-1. Check if that person/company has a brain page
 2. If yes → add a back-link FROM their page TO the page you just created/updated
 3. Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
 4. An unlinked mention is a broken brain.
 
+
+### Contract — steps (( role: reference ))
+
+- Runs in parallel (spawned, never blocks main response)
+
+### Contract — steps 2
+
+> Every time this skill creates or updates a brain page that mentions a person or company:
+1. Check if that person/company has a brain page
 ## Phases
 
-### Phase 1: Idea/Observation Detection (PRIMARY)
+### Phase 1: Idea/Observation Detection (PRIMARY) (( role: reference ))
 
-When the user expresses a novel thought, observation, thesis, or framework:
 - If it's the user's **original thinking** (they generated it) → create/update `originals/{slug}`
 - If it's a **world concept** they're referencing → create/update `concepts/{slug}`
 - If it's a **product or business idea** → create/update `ideas/{slug}`
 
-**Capture exact phrasing.** The user's language IS the insight. Don't paraphrase.
 
-**Cross-linking (MANDATORY):** Every original MUST link to related people, companies,
+### Phase 1: Idea/Observation Detection (PRIMARY) — steps (( role: reference ))
+
+When the user expresses a novel thought, observation, thesis, or framework:
+
+### Phase 1: Idea/Observation Detection (PRIMARY) — steps 2 (( role: reference ))
+
+The user's language IS the insight. Don't paraphrase.
+
+Cross-linking (MANDATORY): Every original MUST link to related people, companies,
 meetings, and concepts. An original without cross-links is a dead original.
 
-### Phase 2: Entity Detection (SECONDARY)
+### Phase 2: Entity Detection (SECONDARY) (( role: reference ))
 
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
 
-### Phase 3: Signal Logging
+
+### Phase 2: Entity Detection (SECONDARY) — steps
+
+2. For each entity:
+   - `gbrain search "name"` — does a page exist?
+
+### Phase 2: Entity Detection (SECONDARY) — steps 2
+
+3. For new FACTS with specific dates → call `gbrain timeline-add <slug> <date> "<summary>"`
+
+### Phase 3: Signal Logging (( role: reference ))
+
+This makes the ambient capture loop debuggable.
+
+
+### Phase 3: Signal Logging — steps (( role: reference ))
 
 Always log a one-line summary:
 - `Signals: 0 ideas, 0 entities, 0 facts (skipped: operational)`
 - `Signals: 1 idea (captured → originals/x), 2 entities (enriched → people/y, companies/z)`
 
-This makes the ambient capture loop debuggable.
-
-## Output Format
+## Output Format (( role: template ))
 
 No visible output to the user. This skill runs silently in the background.
 The output is brain pages created/updated and the signal log line.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Blocking the main response to wait for signal detection to complete
 - Paraphrasing the user's original thinking instead of capturing exact phrasing
```
