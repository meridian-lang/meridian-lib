# Deviation: voice_note_ingest.meri

- Original: `voice-note-ingest/SKILL.md`
- Ported: `voice_note_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 82%
- Lines: 201 -> 232 (+55 / -24)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L32 `The pipeline`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L101 `Brain page format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L147 `Citation format`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L207 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 6/11 (55% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=2
- Judgment: 4 blocks, 0 lines

### Inert section details
- L32 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L50 `Decision tree (where the content goes)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L101 `Brain page format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L147 `Citation format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L165 `Bulk vs. single`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L207 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/voice-note-ingest/SKILL.md
+++ skills/voice_note_ingest.meri
@@ -30,23 +30,28 @@
 > the filing decision protocol.
 
 ## Iron Law
+use judgment to follow the Iron Law guidance:
 
 The user's **exact words** are the insight. Never paraphrase. Never clean
 up. The vivid, unpolished, stream-of-consciousness phrasing captures
 something that cleaned-up prose does not. Preserve it in block quotes.
 The Analysis section can interpret; the transcript section is sacred.
 
+
+### Iron Law — steps
+
 - ✅ `"The ambition-to-lifespan ratio has never been more fucked"`
 - ❌ `User noted the tension between ambition and mortality`
 
-## When to invoke
+## When to invoke (( role: procedure ))
+use judgment to follow the When to invoke guidance:
 
 The user sends an audio or voice message via any channel (Telegram, voice
 memo upload, openclaw audio attachment). The host agent typically provides
 the transcript text. If not, transcribe via `gbrain transcription` (Groq
 Whisper by default; OpenAI fallback for audio > 25MB segmented via ffmpeg).
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 1. STORE       → Upload original audio to gbrain storage backend
@@ -64,38 +69,56 @@
                  (Iron Law per conventions/quality.md).
 ```
 
-## Decision tree (where the content goes)
+## Decision tree (where the content goes) (( inert ))
 
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
 
@@ -143,7 +166,7 @@
 - **YYYY-MM-DD** | voice note from <channel> — [Brief description]
 ```
 
-## Citation format
+## Citation format (( inert ))
 
 ```
 [Source: voice note, <channel>, YYYY-MM-DD]
@@ -161,12 +184,16 @@
   `2026-04-13-rick-rubin-creative-philosophy.ogg`)
 - Brain pages: match the slug of the destination directory.
 
-## Bulk vs. single
+## Bulk vs. single (( inert ))
 
 This skill handles ONE voice note at a time. Each is its own ingest cycle.
+
+### Bulk vs. single — steps
+
 No batching.
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - ❌ **Paraphrasing the transcript.** The exact words are the signal.
 - ❌ **Cleaning up hesitations or filler words** ("um", "like", "you
@@ -176,7 +203,10 @@
 - ❌ **Skipping the audio storage step.** Always upload the original; the
   brain page has a `🔊 [Audio]` link back to it.
 
-## Related skills
+## Related skills (( inert, role: procedure ))
+
+
+### Related skills — steps
 
 - `skills/signal-detector/SKILL.md` — same exact-phrasing pattern for
   text-channel idea capture
@@ -184,7 +214,8 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 
@@ -195,7 +226,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
