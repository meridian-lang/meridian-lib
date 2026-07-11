# Deviation: webhook_transforms.meri

- Original: `webhook-transforms/SKILL.md`
- Ported: `webhook_transforms.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 84 -> 93 (+23 / -14)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `SMS Received`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Meeting Completed`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L59 `Social Mention`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L65 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L70 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Metrics
- Sections inert total: 7/7 (100% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=6, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=56

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L13 `Phases`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L47 `SMS Received`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L53 `Meeting Completed`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L59 `Social Mention`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L65 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L70 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.

## Unified diff

```diff
--- original-skills/webhook-transforms/SKILL.md
+++ skills/webhook_transforms.meri
@@ -18,7 +18,7 @@
 
 # Webhook Transforms
 
-## Contract
+## Contract (( role: reference ))
 
 This skill guarantees:
 - External events are transformed into brain pages with proper citations
@@ -27,55 +27,64 @@
 - Input sanitization: no raw HTML/script passes to brain pages
 - Error handling: transform failure logs raw payload, retries once
 
-## Phases
+## Phases (( role: reference ))
 
 1. **Define transform.** Map event schema to brain page format:
    - Input: raw webhook payload (JSON)
-   - Output: brain page content (markdown) + metadata (slug, type, citations)
-   - Must sanitize: strip HTML tags, escape script content
-
 2. **Register webhook URL.** Provide the external service with the webhook endpoint.
 
 3. **On event received:**
    - Parse payload
    - Run transform function
-   - Write brain page via `gbrain put`
    - Extract entities, run enrichment
    - Add timeline entries to mentioned entities
-   - Sync: `gbrain sync`
-
 4. **Error handling:**
    - If transform throws: log raw payload to `_dead-letter/{timestamp}.md`
    - Surface error type to agent
    - Retry once
    - Don't lose events
 
-## Example Transforms
 
-### SMS Received
+### Phases — steps
+
+   - Output: brain page content (markdown) + metadata (slug, type, citations)
+   - Must sanitize: strip HTML tags, escape script content
+
+
+### Phases — steps 2
+
+   - Write brain page via `gbrain put`
+
+### Phases — steps 3
+
+   - Sync: `gbrain sync`
+
+## Example Transforms (( role: reference ))
+
+### SMS Received (( role: reference ))
 ```
 Input: {from: "+1555...", body: "Meeting moved to 3pm", timestamp: "..."}
 Output: Timeline entry on sender's brain page + task update if action item detected
 ```
 
-### Meeting Completed
+### Meeting Completed (( role: reference ))
 ```
 Input: {title: "Weekly sync", attendees: [...], transcript: "...", summary: "..."}
 Output: Delegate to meeting-ingestion skill
 ```
 
-### Social Mention
+### Social Mention (( role: reference ))
 ```
 Input: {platform: "twitter", author: "@handle", text: "...", url: "..."}
 Output: Brain page in media/ + entity extraction + backlinks
 ```
 
-## Output Format
+## Output Format (( role: template ))
 
 Event transformed and written to brain. Report: "Webhook: {event_type} from {source}
 → {brain_page_path}"
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Passing raw HTML/script to brain pages (XSS risk)
 - Silently dropping events when transform fails (use dead-letter queue)
```
