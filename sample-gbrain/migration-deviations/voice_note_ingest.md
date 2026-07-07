# Deviation: voice_note_ingest.meri

- Original: `voice-note-ingest/SKILL.md`
- Ported: `voice_note_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 201 -> 237 (+61 / -25)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L37 `The pipeline`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `Brain page format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L152 `Citation format`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L201 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L212 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 8/10 (80% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=6, template=2
- Judgment: 1 blocks, 0 lines

### Inert section details
- L37 `The pipeline`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L55 `Decision tree (where the content goes)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L106 `Brain page format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L152 `Citation format`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L170 `Bulk vs. single`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L178 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L201 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L212 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/voice-note-ingest/SKILL.md
+++ skills/voice_note_ingest.meri
@@ -31,10 +31,20 @@
 
 ## Iron Law
 
-The user's **exact words** are the insight. Never paraphrase. Never clean
+
+### Iron Law — steps (( role: reference ))
+
+The user's exact words are the insight. Never paraphrase. Never clean
 up. The vivid, unpolished, stream-of-consciousness phrasing captures
 something that cleaned-up prose does not. Preserve it in block quotes.
+
+### Iron Law — steps 2
+
+use judgment to follow the Iron Law — steps 2 guidance:
 The Analysis section can interpret; the transcript section is sacred.
+
+
+### Iron Law — steps 3
 
 - ✅ `"The ambition-to-lifespan ratio has never been more fucked"`
 - ❌ `User noted the tension between ambition and mortality`
@@ -46,7 +56,7 @@
 the transcript text. If not, transcribe via `gbrain transcription` (Groq
 Whisper by default; OpenAI fallback for audio > 25MB segmented via ffmpeg).
 
-## The pipeline
+## The pipeline (( role: reference ))
 
 ```
 1. STORE       → Upload original audio to gbrain storage backend
@@ -64,38 +74,56 @@
                  (Iron Law per conventions/quality.md).
 ```
 
-## Decision tree (where the content goes)
+## Decision tree (where the content goes) (( role: reference ))
 
 Apply in order. First match wins. If multiple categories apply, file to
 the primary directory and cross-link to the others.
 
 1. **Original idea, observation, or thesis** — the user is expressing a
    novel thought, framework, or connection THEY generated.
-   → `originals/<slug>.md`. Use the user's vivid language for the slug.
-
 2. **About a world concept they encountered** — a framework or model
    someone else created that the user is referencing.
-   → `concepts/<slug>.md`.
-
 3. **About a specific person** — new information, opinion, or observation
    about someone.
-   → Update `people/<person>.md` timeline.
-
 4. **About a specific company** — new info about a company.
-   → Update `companies/<company>.md` timeline.
-
 5. **A product or business idea** — something that could be built.
-   → `ideas/<slug>.md`.
-
 6. **A personal reflection** — therapy-adjacent, emotional, identity.
-   → Append to appropriate `personal/<slug>.md`.
-
-7. **None of the above / random thought / doesn't fit cleanly** —
-   → `voice-notes/YYYY-MM-DD-<slug>.md` (catch-all).
-
 **Multiple categories?** Create the primary page, then cross-link to all
 others. If the voice note covers a person AND a novel idea, create the
 originals/ page AND update the person's timeline.
+
+
+### Decision tree (where the content goes) — steps
+
+   → `originals/<slug>.md`. Use the user's vivid language for the slug.
+
+
+### Decision tree (where the content goes) — steps 2
+
+   → `concepts/<slug>.md`.
+
+
+### Decision tree (where the content goes) — steps 3
+
+   → Update `people/<person>.md` timeline.
+
+
+### Decision tree (where the content goes) — steps 4
+
+   → Update `companies/<company>.md` timeline.
+
+
+### Decision tree (where the content goes) — steps 5
+
+   → `ideas/<slug>.md`.
+
+
+### Decision tree (where the content goes) — steps 6
+
+   → Append to appropriate `personal/<slug>.md`.
+
+7. None of the above / random thought / doesn't fit cleanly —
+   → `voice-notes/YYYY-MM-DD-<slug>.md` (catch-all).
 
 ## Brain page format
 
@@ -143,7 +171,7 @@
 - **YYYY-MM-DD** | voice note from <channel> — [Brief description]
 ```
 
-## Citation format
+## Citation format (( role: reference ))
 
 ```
 [Source: voice note, <channel>, YYYY-MM-DD]
@@ -161,22 +189,30 @@
   `2026-04-13-rick-rubin-creative-philosophy.ogg`)
 - Brain pages: match the slug of the destination directory.
 
-## Bulk vs. single
+## Bulk vs. single (( role: reference ))
 
 This skill handles ONE voice note at a time. Each is its own ingest cycle.
+
+### Bulk vs. single — steps
+
 No batching.
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - ❌ **Paraphrasing the transcript.** The exact words are the signal.
 - ❌ **Cleaning up hesitations or filler words** ("um", "like", "you
   know"). The texture matters.
 - ❌ **Creating a page with no entity cross-links** when people/companies
   were mentioned. Iron Law fail.
-- ❌ **Skipping the audio storage step.** Always upload the original; the
-  brain page has a `🔊 [Audio]` link back to it.
+
+### Anti-Patterns — steps (( role: reference ))
+
+- ❌ Skipping the audio storage step. Always upload the original; the brain page has a `🔊 [Audio]` link back to it.
 
 ## Related skills
+
+
+### Related skills — steps
 
 - `skills/signal-detector/SKILL.md` — same exact-phrasing pattern for
   text-channel idea capture
@@ -184,7 +220,7 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 
@@ -195,7 +231,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
