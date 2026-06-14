# Deviation: voice_note_ingest.meri

- Original: `voice-note-ingest/SKILL.md`
- Ported: `voice_note_ingest.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 201 -> 203 (+34 / -32)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 8/12 inert (67% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=2
- Judgment: 1 blocks, 3 lines

### Inert section details
- L10 `Iron Law`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L27 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L45 `Decision tree (where the content goes)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L78 `Brain page format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L124 `Citation format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L142 `Bulk vs. single`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L158 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L178 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/voice-note-ingest/SKILL.md
+++ skills/voice_note_ingest.meri
@@ -29,7 +29,7 @@
 > **Convention:** see [_brain-filing-rules.md](../_brain-filing-rules.md) for
 > the filing decision protocol.
 
-## Iron Law
+## Iron Law (( inert ))
 
 The user's **exact words** are the insight. Never paraphrase. Never clean
 up. The vivid, unpolished, stream-of-consciousness phrasing captures
@@ -46,7 +46,7 @@
 the transcript text. If not, transcribe via `gbrain transcription` (Groq
 Whisper by default; OpenAI fallback for audio > 25MB segmented via ffmpeg).
 
-## The pipeline
+## The pipeline (( inert ))
 
 ```
 1. STORE       → Upload original audio to gbrain storage backend
@@ -64,7 +64,7 @@
                  (Iron Law per conventions/quality.md).
 ```
 
-## Decision tree (where the content goes)
+## Decision tree (where the content goes) (( inert ))
 
 Apply in order. First match wins. If multiple categories apply, file to
 the primary directory and cross-link to the others.
@@ -120,30 +120,30 @@
 
 > Executive summary of what was said and why it matters.
 
-## User's Words
+## User's Words (( inert ))
 
 > "Exact transcript, verbatim, preserving every word, hesitation, and verbal
 > tic. This is the primary source material. Do not edit."
 
 🔊 [Audio]([gbrain storage URL or relative path])
 
-## Analysis
+## Analysis (( inert ))
 
 [What this means, why it matters, connections to other thinking. The
 analysis is the agent's interpretation; the transcript above is sacred.]
 
-## See Also
+## See Also (( inert ))
 
 - [Related brain pages with relative links]
 
 ---
 
-## Timeline
+## Timeline (( inert ))
 
 - **YYYY-MM-DD** | voice note from <channel> — [Brief description]
 ```
 
-## Citation format
+## Citation format (( inert ))
 
 ```
 [Source: voice note, <channel>, YYYY-MM-DD]
@@ -155,28 +155,29 @@
 [Source: voice note, <channel>, YYYY-MM-DD HH:MM PT]
 ```
 
-## Naming convention
-
-- Audio files: `YYYY-MM-DD-<brief-slug>.<ext>` (e.g.,
-  `2026-04-13-rick-rubin-creative-philosophy.ogg`)
-- Brain pages: match the slug of the destination directory.
-
-## Bulk vs. single
+## Naming convention (( role: procedure ))
+
+use judgment to follow the Naming convention guidance:
+  item: Audio files: `YYYY-MM-DD-<brief-slug>.<ext>` (e.g.,
+    `2026-04-13-rick-rubin-creative-philosophy.ogg`)
+  item: Brain pages: match the slug of the destination directory.
+## Bulk vs. single (( inert ))
 
 This skill handles ONE voice note at a time. Each is its own ingest cycle.
 No batching.
 
-## Anti-Patterns
-
-- ❌ **Paraphrasing the transcript.** The exact words are the signal.
-- ❌ **Cleaning up hesitations or filler words** ("um", "like", "you
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] ❌ **Paraphrasing the transcript.** The exact words are the signal.
+- [ ] ❌ **Cleaning up hesitations or filler words** ("um", "like", "you
   know"). The texture matters.
-- ❌ **Creating a page with no entity cross-links** when people/companies
+- [ ] ❌ **Creating a page with no entity cross-links** when people/companies
   were mentioned. Iron Law fail.
-- ❌ **Skipping the audio storage step.** Always upload the original; the
+- [ ] ❌ **Skipping the audio storage step.** Always upload the original; the
   brain page has a `🔊 [Audio]` link back to it.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/signal-detector/SKILL.md` — same exact-phrasing pattern for
   text-channel idea capture
@@ -184,16 +185,17 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
-
-This skill guarantees:
-
-- Routing matches the canonical triggers in the frontmatter.
-- Output written under the directories listed in `writes_to:` (when applicable).
-- Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
-- Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
-
-The full behavior contract is documented in the body sections above; this section exists for the conformance test.
+## Contract (( role: procedure ))
+
+> This skill guarantees:
+
+!!! checklist (( ai-autonomy ))
+- [ ] Routing matches the canonical triggers in the frontmatter.
+- [ ] Output written under the directories listed in `writes_to:` (when applicable).
+- [ ] Conventions referenced (`quality.md`, `brain-first.md`, `_brain-filing-rules.md`) are followed.
+- [ ] Privacy contract preserved: no real names, no fork-specific filesystem path literals, no upstream-fork references.
+
+> The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
 ## Output Format
 
```
