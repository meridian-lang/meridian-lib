# Deviation: rotatecredentials.meri

- Original: `rotate_credentials/SKILL.md`
- Ported: `rotatecredentials.meri`
- Tier: 2 (light edits)
- Similarity: 79%
- Lines: 53 -> 53 (+11 / -11)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L13 `When to invoke`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 36 non-blank ported lines
- Sections inert total: 3/5 (60% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=33

### Inert section details
- L13 `When to invoke`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L30 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L41 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/rotate_credentials/SKILL.md
+++ skills/rotatecredentials.meri
@@ -9,16 +9,16 @@
 
 # Rotate Credentials
 
-A credential that's gone stale is a liability whether or not anyone notices.
-Rather than wait for a security review to flag it, this skill sweeps every
-active credential, checks its age against the freshness window, and rotates
-anything that's fallen out of it. Because a rotation call to the identity
-provider can fail transiently, the loop doesn't stop at the first attempt —
-it waits and retries until the credential actually comes back fresh, so a
-flaky provider call doesn't leave a stale credential looking "handled" when
-it isn't.
+> A credential that's gone stale is a liability whether or not anyone notices.
+> Rather than wait for a security review to flag it, this skill sweeps every
+> active credential, checks its age against the freshness window, and rotates
+> anything that's fallen out of it. Because a rotation call to the identity
+> provider can fail transiently, the loop doesn't stop at the first attempt —
+> it waits and retries until the credential actually comes back fresh, so a
+> flaky provider call doesn't leave a stale credential looking "handled" when
+> it isn't.
 
-## When to invoke
+## When to invoke (( role: reference ))
 - "rotate credentials"
 - "rotate stale credentials"
 - "run the credential rotation pass"
@@ -35,7 +35,7 @@
     rotate a credential.
 Emit: "credential rotation pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't rotate a credential once and move on without checking whether the
   provider actually applied the rotation — the retry loop exists because a
   single rotation call isn't proof of a fresh credential.
@@ -46,7 +46,7 @@
 ## Guarantees
 make sure no credentials whose status is "active" and whose use count is more than its use limit.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt confirms every active credential is fresh at the end of the
 pass, or names which ones are still cycling if the provider is slow to
 confirm.
```
