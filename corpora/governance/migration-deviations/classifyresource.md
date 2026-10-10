# Deviation: classifyresource.meri

- Original: `classify_resource/SKILL.md`
- Ported: `classifyresource.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 57 -> 60 (+15 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L40 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L48 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 40 non-blank ported lines
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=6, structure=0, desugar=0, meaning=44

### Inert section details
- L40 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L48 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/classify_resource/SKILL.md
+++ skills/classifyresource.meri
@@ -9,13 +9,13 @@
 
 # Classify Resource
 
-Every access decision this corpus makes — `grant access`'s classified-gate
-check, the `access matrix` render, the coverage thresholds in
-`policy audit` — assumes a resource already knows whether it's classified.
-This skill is where that assumption gets made true. It fetches the pending
-queue, applies a fast discretionary rule for the obvious cases, and for
-anything that isn't obvious, hands the call to judgment rather than
-defaulting a resource to "public" just because nobody decided otherwise.
+> Every access decision this corpus makes — `grant access`'s classified-gate
+> check, the `access matrix` render, the coverage thresholds in
+> `policy audit` — assumes a resource already knows whether it's classified.
+> This skill is where that assumption gets made true. It fetches the pending
+> queue, applies a fast discretionary rule for the obvious cases, and for
+> anything that isn't obvious, hands the call to judgment rather than
+> defaulting a resource to "public" just because nobody decided otherwise.
 
 ## When to invoke
 - "classify resources"
@@ -26,12 +26,15 @@
 fetch pending access requests.
 
 !!! table (( ai-discretion ))
-| Condition                          | Action                          |
+| Condition             | Action             |
 | ------------------------------------ | ---------------------------------- |
-| the resource's status is "unclassified" | escalate to the security team    |
-| *                                   | monitor the resource             |
+| the resource's status is "unclassified" | escalate to the security team  |
+| *                  | monitor the resource       |
 
 ## Classification Routing
+
+### Classification Routing — steps
+
 for each access request:
   bind should classify = decide whether the access request's resource looks sensitive.
   if the should classify is true,
@@ -42,7 +45,7 @@
 ## Completion
 Emit: "classify resource pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't default an unclassified resource to "public" to unblock a pending
   request. Silence isn't a classification decision — either the
   discretion table catches it or judgment does.
@@ -50,7 +53,7 @@
   discretion table exists so the obvious cases don't burn a judgment call
   that the ambiguous cases actually need.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt notes how many resources were escalated outright versus routed
 to judgment, so a security officer can see whether the ambiguous share is
 growing.
```
