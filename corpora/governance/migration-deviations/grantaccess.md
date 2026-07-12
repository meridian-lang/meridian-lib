# Deviation: grantaccess.meri

- Original: `grant_access/SKILL.md`
- Ported: `grantaccess.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 71 -> 80 (+22 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L15 `Contract`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L48 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L67 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 55 non-blank ported lines
- Sections inert total: 3/4 (75% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=4, structure=0, desugar=0, meaning=52

### Inert section details
- L15 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L48 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L67 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/grant_access/SKILL.md
+++ skills/grantaccess.meri
@@ -10,18 +10,18 @@
 
 # Grant Access
 
-Access requests arrive faster than a human reviewer can read them one at a
-time, but blanket auto-approval is how a compromised account ends up with
-standing access to a resource it never needed. This skill sits between the
-two extremes: it evaluates the requesting user against the resource's
-classification and the user's own role and clearance, grants automatically
-when the policy clearly allows it, and defers to a security officer only
-when the resource is classified and the policy says so explicitly. It is the
-default entrypoint for any "can this user reach that resource" question — do
-not hand-approve a request in a ticket instead of running this skill, because
-a hand-approval leaves no audit trail and no policy evaluation behind it.
+> Access requests arrive faster than a human reviewer can read them one at a
+> time, but blanket auto-approval is how a compromised account ends up with
+> standing access to a resource it never needed. This skill sits between the
+> two extremes: it evaluates the requesting user against the resource's
+> classification and the user's own role and clearance, grants automatically
+> when the policy clearly allows it, and defers to a security officer only
+> when the resource is classified and the policy says so explicitly. It is the
+> default entrypoint for any "can this user reach that resource" question — do
+> not hand-approve a request in a ticket instead of running this skill, because
+> a hand-approval leaves no audit trail and no policy evaluation behind it.
 
-## Contract
+## Contract (( role: reference ))
 - Input: a user and the resource they are requesting access to.
 - Output: either a completed grant, a denial, or an access request parked
   pending security-officer sign-off.
@@ -35,11 +35,17 @@
 - "authorize resource access"
 
 ## Rules
+
+### Rules — steps
+
 A user with clearance "denied" must not access classified resources.
 A user with role admin may access classified resources.
 An access request for a classified resource must be approved by a security officer before the grant.
 
 ## Workflow
+
+### Workflow — steps
+
 if the user is authorized,
   grant access to the resource for the user.
   recover from access.denied:
@@ -48,7 +54,7 @@
   Note: "user not authorized for this resource".
 Emit: "grant access pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't bypass this skill for "just this once" requests — every ad hoc grant
   is exactly the kind of standing access `revoke stale access` exists to
   clean up later, and by then nobody remembers why it was granted.
@@ -57,6 +63,9 @@
   the grant auditable.
 
 ## When NOT to use this skill
+
+### When NOT to use this skill — steps (( role: reference ))
+
 Route a request to `review requests` instead when a human reviewer, not a
 policy evaluation, is the point of the ask — for example a backlog of
 requests waiting on a reviewer's judgment rather than a clean allow/deny.
@@ -64,7 +73,7 @@
 have a classification yet; granting or denying access to an unclassified
 resource is premature.
 
-## Report shape
+## Report shape (( role: template ))
 The receipt records whether access was granted, denied, or escalated for
 manual review, plus the security-officer approval reference when the
 resource was classified.
```
