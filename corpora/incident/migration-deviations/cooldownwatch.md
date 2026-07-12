# Deviation: cooldownwatch.meri

- Original: `cooldown_watch/SKILL.md`
- Ported: `cooldownwatch.meri`
- Tier: 2 (light edits)
- Similarity: 78%
- Lines: 48 -> 52 (+13 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L41 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 34 non-blank ported lines
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 1 blocks, 0 lines
- canonical_drift: synonym=8, structure=0, desugar=0, meaning=28

### Inert section details
- L26 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/cooldown_watch/SKILL.md
+++ skills/cooldownwatch.meri
@@ -9,13 +9,13 @@
 
 # Cooldown Watch
 
-An alert that flaps — firing, clearing, firing again — can page the same
-engineer over and over for what's genuinely a single unresolved condition.
-This skill exists to smooth that out: it acknowledges each firing alert
-that isn't already stale, then holds for a fixed cooldown window before
-anything is allowed to re-page. The cooldown isn't about ignoring the
-alert; it's about giving the underlying condition a chance to actually
-clear before treating another firing as a new event.
+> An alert that flaps — firing, clearing, firing again — can page the same
+> engineer over and over for what's genuinely a single unresolved condition.
+> This skill exists to smooth that out: it acknowledges each firing alert
+> that isn't already stale, then holds for a fixed cooldown window before
+> anything is allowed to re-page. The cooldown isn't about ignoring the
+> alert; it's about giving the underlying condition a chance to actually
+> clear before treating another firing as a new event.
 
 ## When to invoke
 - "watch alert cooldown"
@@ -31,10 +31,14 @@
 wait 10 minutes.
 Post: "cooldown watch pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't acknowledge a stale alert just to clear it from the firing list.
   A stale alert usually means the underlying signal is unreliable, not
   resolved — acknowledging it hides that distinction.
+
+### Anti-Patterns — steps
+
+use judgment to follow the Anti-Patterns — steps guidance:
 - Don't shorten the cooldown window to make the receipt look cleaner
   faster. The window exists so a genuinely flapping alert gets time to
   settle before this skill decides it's done.
@@ -42,7 +46,7 @@
 ## Guarantees
 make sure no alerts whose fired at is within the last 15 minutes and whose status is "firing".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt confirms no alert both fired within the cooldown window and is
 still firing by the time the pass completes.
 
```
