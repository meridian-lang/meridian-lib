# Deviation: voice_note_ingest.meri

- Original: `voice-note-ingest/SKILL.md`
- Ported: `voice_note_ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 94%
- Lines: 201 -> 201 (+13 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 11/12 inert (92% inert ratio)
- Judgment: 0 blocks, 0 lines

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
@@ -155,18 +155,18 @@
 [Source: voice note, <channel>, YYYY-MM-DD HH:MM PT]
 ```
 
-## Naming convention
+## Naming convention (( inert ))
 
 - Audio files: `YYYY-MM-DD-<brief-slug>.<ext>` (e.g.,
   `2026-04-13-rick-rubin-creative-philosophy.ogg`)
 - Brain pages: match the slug of the destination directory.
 
-## Bulk vs. single
+## Bulk vs. single (( inert ))
 
 This skill handles ONE voice note at a time. Each is its own ingest cycle.
 No batching.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - ❌ **Paraphrasing the transcript.** The exact words are the signal.
 - ❌ **Cleaning up hesitations or filler words** ("um", "like", "you
@@ -176,7 +176,7 @@
 - ❌ **Skipping the audio storage step.** Always upload the original; the
   brain page has a `🔊 [Audio]` link back to it.
 
-## Related skills
+## Related skills (( inert ))
 
 - `skills/signal-detector/SKILL.md` — same exact-phrasing pattern for
   text-channel idea capture
@@ -184,7 +184,7 @@
 - `skills/conventions/quality.md` — citation + back-link rules
 
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 
```
