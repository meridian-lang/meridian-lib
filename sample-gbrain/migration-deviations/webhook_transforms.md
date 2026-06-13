# Deviation: webhook_transforms.meri

- Original: `webhook-transforms/SKILL.md`
- Ported: `webhook_transforms.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 84 -> 73 (+14 / -25)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 7/8 inert (88% inert ratio)
- Judgment: 1 blocks, 4 lines

## Unified diff

```diff
--- original-skills/webhook-transforms/SKILL.md
+++ webhook_transforms.meri
@@ -18,7 +18,7 @@
 
 # Webhook Transforms
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 This skill guarantees:
 - External events are transformed into brain pages with proper citations
@@ -29,42 +29,31 @@
 
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
@@ -75,7 +64,7 @@
 Event transformed and written to brain. Report: "Webhook: {event_type} from {source}
 → {brain_page_path}"
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Passing raw HTML/script to brain pages (XSS risk)
 - Silently dropping events when transform fails (use dead-letter queue)
```
