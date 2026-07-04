# Deviation: voice_note_ingest.meri

- Original: `voice-note-ingest/SKILL.md`
- Ported: `voice_note_ingest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 92%
- Lines: 201 -> 201 (+16 / -16)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L10 `Iron Law`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L20 `When to invoke`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.
- L27 `The pipeline`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L45 `Decision tree (where the content goes)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L78 `Brain page format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L124 `Citation format`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L136 `Naming convention`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L142 `Bulk vs. single`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L147 `Anti-Patterns`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L157 `Related skills`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L165 `Contract`: normative-contract - Normative invariants prose needs mining into assertions or explicit AI routing.
- L176 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections: 12/12 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=8, template=2
- Judgment: 0 blocks, 0 lines

### Inert section details
- L10 `Iron Law`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L20 `When to invoke`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L27 `The pipeline`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L45 `Decision tree (where the content goes)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L78 `Brain page format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L124 `Citation format`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L136 `Naming convention`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L142 `Bulk vs. single`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L147 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L157 `Related skills`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L165 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L176 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

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
@@ -39,14 +39,14 @@
 - ✅ `"The ambition-to-lifespan ratio has never been more fucked"`
 - ❌ `User noted the tension between ambition and mortality`
 
-## When to invoke
+## When to invoke (( inert, role: applicability ))
 
 The user sends an audio or voice message via any channel (Telegram, voice
 memo upload, openclaw audio attachment). The host agent typically provides
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
@@ -97,7 +97,7 @@
 others. If the voice note covers a person AND a novel idea, create the
 originals/ page AND update the person's timeline.
 
-## Brain page format
+## Brain page format (( inert, role: template ))
 
 For ALL voice-note-derived pages, include this skeleton:
 
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
 
@@ -195,7 +195,7 @@
 
 The full behavior contract is documented in the body sections above; this section exists for the conformance test.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 The skill's output shape is documented inline in the body sections above (see "Output", "Brain page format", or equivalent). The literal section header here exists for the conformance test (`test/skills-conformance.test.ts`).
 
```
