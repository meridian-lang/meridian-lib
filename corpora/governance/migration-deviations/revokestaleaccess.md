# Deviation: revokestaleaccess.meri

- Original: `revoke_stale_access/SKILL.md`
- Ported: `revokestaleaccess.meri`
- Tier: 2 (light edits)
- Similarity: 80%
- Lines: 46 -> 46 (+9 / -9)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L24 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 2/5 (40% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L24 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L35 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/revoke_stale_access/SKILL.md
+++ skills/revokestaleaccess.meri
@@ -9,13 +9,13 @@
 
 # Revoke Stale Access
 
-Access that's still granted long after the reason for it has expired is one
-of the most common findings in any real access audit, and it's rarely
-malicious — it's just leftover. This skill closes that gap: it fetches
-pending access requests, counts how many are sitting in the granted state,
-and revokes them one at a time so the audit trail shows exactly what was
-pulled back and why. Pair it with a regular `review requests` cadence so the
-queue that feeds it doesn't grow faster than this sweep can clear it.
+> Access that's still granted long after the reason for it has expired is one
+> of the most common findings in any real access audit, and it's rarely
+> malicious — it's just leftover. This skill closes that gap: it fetches
+> pending access requests, counts how many are sitting in the granted state,
+> and revokes them one at a time so the audit trail shows exactly what was
+> pulled back and why. Pair it with a regular `review requests` cadence so the
+> queue that feeds it doesn't grow faster than this sweep can clear it.
 
 ## When to invoke
 - "revoke stale access"
@@ -29,7 +29,7 @@
   revoke the access request.
 Emit: "revoke stale access pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't revoke access in bulk without recording the count first — the
   `revoked count` line exists so the receipt can say exactly how many
   grants were pulled back, not just that "some" were.
@@ -40,7 +40,7 @@
 ## Guarantees
 make sure no users whose clearance is "denied" and whose status is "active".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt states the revoked count for this pass, so a security officer
 can track whether the sweep's workload is trending up or down over time.
 
```
