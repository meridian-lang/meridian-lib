# Deviation: webhook_transforms.meri

- Original: `webhook-transforms/SKILL.md`
- Ported: `webhook_transforms.meri`
- Tier: 1 (near-verbatim)
- Similarity: 90%
- Lines: 84 -> 84 (+8 / -8)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 8/8 inert (100% inert ratio)
- Operational inert: 2
- Unclassified inert: 0
- Inert categories: normative-contract=1, operational-procedure=1, reference-documentation=5, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `Contract`: normative-contract — Normative invariants prose needs mining into assertions or explicit AI routing.
- L13 `Phases`: operational-procedure — Marked or derived as procedure, but inert suppresses execution.
- L36 `Example Transforms`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L38 `SMS Received`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L44 `Meeting Completed`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L50 `Social Mention`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L56 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L61 `Anti-Patterns`: reference-documentation — Reference documentation, rationale, examples, or changelog.

## Unified diff

```diff
--- original-skills/webhook-transforms/SKILL.md
+++ skills/webhook_transforms.meri
@@ -18,7 +18,7 @@
 
 # Webhook Transforms
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - External events are transformed into brain pages with proper citations
@@ -27,7 +27,7 @@
 - Input sanitization: no raw HTML/script passes to brain pages
 - Error handling: transform failure logs raw payload, retries once
 
-## Phases
+## Phases (( inert, role: procedure ))
 
 1. **Define transform.** Map event schema to brain page format:
    - Input: raw webhook payload (JSON)
@@ -50,32 +50,32 @@
    - Retry once
    - Don't lose events
 
-## Example Transforms
+## Example Transforms (( inert ))
 
-### SMS Received
+### SMS Received (( inert ))
 ```
 Input: {from: "+1555...", body: "Meeting moved to 3pm", timestamp: "..."}
 Output: Timeline entry on sender's brain page + task update if action item detected
 ```
 
-### Meeting Completed
+### Meeting Completed (( inert ))
 ```
 Input: {title: "Weekly sync", attendees: [...], transcript: "...", summary: "..."}
 Output: Delegate to meeting-ingestion skill
 ```
 
-### Social Mention
+### Social Mention (( inert ))
 ```
 Input: {platform: "twitter", author: "@handle", text: "...", url: "..."}
 Output: Brain page in media/ + entity extraction + backlinks
 ```
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 Event transformed and written to brain. Report: "Webhook: {event_type} from {source}
 → {brain_page_path}"
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Passing raw HTML/script to brain pages (XSS risk)
 - Silently dropping events when transform fails (use dead-letter queue)
```
