# Deviation: webhook_transforms.meri

- Original: `webhook-transforms/SKILL.md`
- Ported: `webhook_transforms.meri`
- Tier: 2 (light edits)
- Similarity: 62%
- Lines: 84 -> 75 (+26 / -35)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 5/8 inert (62% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=4, template=1
- Judgment: 1 blocks, 4 lines

### Inert section details
- L26 `Example Transforms`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L28 `SMS Received`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L34 `Meeting Completed`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L40 `Social Mention`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L46 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/webhook-transforms/SKILL.md
+++ skills/webhook_transforms.meri
@@ -18,53 +18,43 @@
 
 # Webhook Transforms
 
-## Contract
+## Contract (( role: procedure ))
 
-This skill guarantees:
-- External events are transformed into brain pages with proper citations
-- Raw payloads are preserved (dead-letter queue if transform fails)
-- Entity extraction runs on every transformed event
-- Input sanitization: no raw HTML/script passes to brain pages
-- Error handling: transform failure logs raw payload, retries once
+> This skill guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] External events are transformed into brain pages with proper citations
+- [ ] Raw payloads are preserved (dead-letter queue if transform fails)
+- [ ] Entity extraction runs on every transformed event
+- [ ] Input sanitization: no raw HTML/script passes to brain pages
+- [ ] Error handling: transform failure logs raw payload, retries once
 
 ## Phases
 
-1. **Define transform.** Map event schema to brain page format:
-   - Input: raw webhook payload (JSON)
-   - Output: brain page content (markdown) + metadata (slug, type, citations)
-   - Must sanitize: strip HTML tags, escape script content
+use judgment to define and run a webhook transform:
+  Map the event schema to the brain page format, sanitizing HTML and escaping script content.
+  Register the webhook URL with the external service.
+  On each event, parse the payload, run the transform, write the page, extract entities, enrich, and add timeline entries.
+  On a transform failure, log the raw payload to a dead-letter file, surface the error type, and retry once without losing events.
 
-2. **Register webhook URL.** Provide the external service with the webhook endpoint.
+```bash
+gbrain sync
+```
 
-3. **On event received:**
-   - Parse payload
-   - Run transform function
-   - Write brain page via `gbrain put`
-   - Extract entities, run enrichment
-   - Add timeline entries to mentioned entities
-   - Sync: `gbrain sync`
+## Example Transforms (( inert ))
 
-4. **Error handling:**
-   - If transform throws: log raw payload to `_dead-letter/{timestamp}.md`
-   - Surface error type to agent
-   - Retry once
-   - Don't lose events
-
-## Example Transforms
-
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
@@ -75,10 +65,11 @@
 Event transformed and written to brain. Report: "Webhook: {event_type} from {source}
 → {brain_page_path}"
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
 
-- Passing raw HTML/script to brain pages (XSS risk)
-- Silently dropping events when transform fails (use dead-letter queue)
-- Processing webhooks without entity extraction
-- Not sanitizing external input before brain writes
+!!! checklist (( ai-autonomy ))
+- [ ] Passing raw HTML/script to brain pages (XSS risk)
+- [ ] Silently dropping events when transform fails (use dead-letter queue)
+- [ ] Processing webhooks without entity extraction
+- [ ] Not sanitizing external input before brain writes
 
```
