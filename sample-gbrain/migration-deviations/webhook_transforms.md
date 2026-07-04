# Deviation: webhook_transforms.meri

- Original: `webhook-transforms/SKILL.md`
- Ported: `webhook_transforms.meri`
- Tier: 2 (light edits)
- Similarity: 81%
- Lines: 84 -> 96 (+23 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L49 `SMS Received`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L55 `Meeting Completed`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L61 `Social Mention`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L67 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 4/7 (57% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=3, template=1
- Judgment: 3 blocks, 0 lines

### Inert section details
- L49 `SMS Received`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L55 `Meeting Completed`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L61 `Social Mention`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L67 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/webhook-transforms/SKILL.md
+++ skills/webhook_transforms.meri
@@ -18,7 +18,8 @@
 
 # Webhook Transforms
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 This skill guarantees:
 - External events are transformed into brain pages with proper citations
@@ -28,10 +29,10 @@
 - Error handling: transform failure logs raw payload, retries once
 
 ## Phases
+use judgment to follow the Phases guidance:
 
 1. **Define transform.** Map event schema to brain page format:
    - Input: raw webhook payload (JSON)
-   - Output: brain page content (markdown) + metadata (slug, type, citations)
    - Must sanitize: strip HTML tags, escape script content
 
 2. **Register webhook URL.** Provide the external service with the webhook endpoint.
@@ -39,43 +40,54 @@
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
+
+### Phases — steps 2
+
+   - Write brain page via `gbrain put`
+
+### Phases — steps 3
+
+   - Sync: `gbrain sync`
+
+## Example Transforms (( inert ))
+
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
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Passing raw HTML/script to brain pages (XSS risk)
 - Silently dropping events when transform fails (use dead-letter queue)
```
