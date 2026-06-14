# Deviation: signal_detector.meri

- Original: `signal-detector/SKILL.md`
- Ported: `signal_detector.meri`
- Tier: 3 (structural rewrite)
- Similarity: 46%
- Lines: 113 -> 115 (+63 / -61)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- preamble-blockquoted
- command-hole-rewritten

## Metrics
- Sections: 2/8 inert (25% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: template=1, tools-metadata=1
- Judgment: 3 blocks, 22 lines

### Inert section details
- L70 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L84 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/signal-detector/SKILL.md
+++ skills/signal_detector.meri
@@ -24,83 +24,85 @@
 
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
 
-This skill guarantees:
-- Fires on every message (no exceptions unless purely operational)
-- Runs in parallel (spawned, never blocks main response)
-- Captures ideas with the user's EXACT phrasing (no paraphrasing)
-- Detects entity mentions and creates/enriches brain pages
-- Logs a one-line summary of what was captured
-- Back-links all entity mentions (Iron Law)
-- Citations on every fact written
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Fires on every message (no exceptions unless purely operational)
+- [ ] Runs in parallel (spawned, never blocks main response)
+- [ ] Captures ideas with the user's EXACT phrasing (no paraphrasing)
+- [ ] Detects entity mentions and creates/enriches brain pages
+- [ ] Logs a one-line summary of what was captured
+- [ ] Back-links all entity mentions (Iron Law)
+- [ ] Citations on every fact written
 
-> **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
+> > **Convention:** See `skills/conventions/quality.md` for Iron Law back-linking.
 
-Every time this skill creates or updates a brain page that mentions a person or company:
-1. Check if that person/company has a brain page
-2. If yes → add a back-link FROM their page TO the page you just created/updated
-3. Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
-4. An unlinked mention is a broken brain.
+> Every time this skill creates or updates a brain page that mentions a person or company:
+> 1. Check if that person/company has a brain page
+> 2. If yes → add a back-link FROM their page TO the page you just created/updated
+> 3. Format: `- **YYYY-MM-DD** | Referenced in [page title](path) — brief context`
+> 4. An unlinked mention is a broken brain.
 
 ## Phases
 
-### Phase 1: Idea/Observation Detection (PRIMARY)
+### Phase 1: Idea/Observation Detection (PRIMARY) (( role: procedure ))
 
-When the user expresses a novel thought, observation, thesis, or framework:
-- If it's the user's **original thinking** (they generated it) → create/update `originals/{slug}`
-- If it's a **world concept** they're referencing → create/update `concepts/{slug}`
-- If it's a **product or business idea** → create/update `ideas/{slug}`
-
-**Capture exact phrasing.** The user's language IS the insight. Don't paraphrase.
-
-**Cross-linking (MANDATORY):** Every original MUST link to related people, companies,
-meetings, and concepts. An original without cross-links is a dead original.
-
-### Phase 2: Entity Detection (SECONDARY)
-
-1. Extract entity mentions (people, companies, media titles)
-2. For each entity:
-   - `gbrain search "name"` — does a page exist?
-   - If NO page → check notability. If notable, create page with enrichment.
-   - If page exists but THIN → trigger enrich
-   - If page exists and RICH → no action
-3. For new FACTS with specific dates → call `gbrain timeline-add <slug> <date> "<summary>"`
-
-**Auto-link (v0.10.1):** When you write/update an originals or ideas page that
-references a person or company, the auto-link post-hook on `put_page`
-automatically creates the link from the new page to that entity. You don't
-need to call `gbrain link` manually. Timeline entries still need explicit calls.
-
-### Phase 3: Signal Logging
-
-Always log a one-line summary:
-- `Signals: 0 ideas, 0 entities, 0 facts (skipped: operational)`
-- `Signals: 1 idea (captured → originals/x), 2 entities (enriched → people/y, companies/z)`
-
-This makes the ambient capture loop debuggable.
-
+use judgment to follow the Phase 1: Idea/Observation Detection (PRIMARY) guidance:
+  When the user expresses a novel thought, observation, thesis, or framework:
+  item: If it's the user's **original thinking** (they generated it) → create/update `originals/{slug}`
+  item: If it's a **world concept** they're referencing → create/update `concepts/{slug}`
+  item: If it's a **product or business idea** → create/update `ideas/{slug}`
+  
+  **Capture exact phrasing.** The user's language IS the insight. Don't paraphrase.
+  
+  **Cross-linking (MANDATORY):** Every original MUST link to related people, companies,
+  meetings, and concepts. An original without cross-links is a dead original.
+### Phase 2: Entity Detection (SECONDARY) (( role: procedure ))
+  
+use judgment to follow the Phase 2: Entity Detection (SECONDARY) guidance:
+  1. Extract entity mentions (people, companies, media titles)
+  2. For each entity:
+  item: `gbrain search "name"` — does a page exist?
+  item: If NO page → check notability. If notable, create page with enrichment.
+  item: If page exists but THIN → trigger enrich
+  item: If page exists and RICH → no action
+  3. For new FACTS with specific dates → call `gbrain timeline-add <slug> <date> "<summary>"`
+  
+  **Auto-link (v0.10.1):** When you write/update an originals or ideas page that
+  references a person or company, the auto-link post-hook on `put_page`
+  automatically creates the link from the new page to that entity. You don't
+  need to call `gbrain link` manually. Timeline entries still need explicit calls.
+### Phase 3: Signal Logging (( role: procedure ))
+  
+use judgment to follow the Phase 3: Signal Logging guidance:
+  Always log a one-line summary:
+  item: `Signals: 0 ideas, 0 entities, 0 facts (skipped: operational)`
+  item: `Signals: 1 idea (captured → originals/x), 2 entities (enriched → people/y, companies/z)`
+  
+  This makes the ambient capture loop debuggable.
 ## Output Format
 
 No visible output to the user. This skill runs silently in the background.
 The output is brain pages created/updated and the signal log line.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Blocking the main response to wait for signal detection to complete
-- Paraphrasing the user's original thinking instead of capturing exact phrasing
-- Creating pages for non-notable entities (one-off mentions)
-- Skipping back-links after creating/updating pages
-- Running on purely operational messages ("ok", "thanks", "do it")
+!!! checklist (( ai-autonomy ))
+- [ ] Blocking the main response to wait for signal detection to complete
+- [ ] Paraphrasing the user's original thinking instead of capturing exact phrasing
+- [ ] Creating pages for non-notable entities (one-off mentions)
+- [ ] Skipping back-links after creating/updating pages
+- [ ] Running on purely operational messages ("ok", "thanks", "do it")
 
 ## Tools Used
 
```
