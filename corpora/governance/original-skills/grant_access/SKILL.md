---
name: grant access
description: Evaluate a user's clearance and role before granting access to a resource, routing classified-resource requests through a security-officer approval gate instead of granting on request alone. Use this whenever an access request needs a real authorization decision rather than a rubber stamp.
triggers:
  - "grant access"
  - "grant resource access"
  - "authorize resource access"
parameters: user, resource
---

# Grant Access

Access requests arrive faster than a human reviewer can read them one at a
time, but blanket auto-approval is how a compromised account ends up with
standing access to a resource it never needed. This skill sits between the
two extremes: it evaluates the requesting user against the resource's
classification and the user's own role and clearance, grants automatically
when the policy clearly allows it, and defers to a security officer only
when the resource is classified and the policy says so explicitly. It is the
default entrypoint for any "can this user reach that resource" question — do
not hand-approve a request in a ticket instead of running this skill, because
a hand-approval leaves no audit trail and no policy evaluation behind it.

## Contract
- Input: a user and the resource they are requesting access to.
- Output: either a completed grant, a denial, or an access request parked
  pending security-officer sign-off.
- Side effect: a classified grant carries an approval record from the
  security officer; a denial gets logged for the next `revoke stale access`
  sweep.

## When to invoke
- "grant access"
- "grant resource access"
- "authorize resource access"

## Rules
A user with clearance "denied" must not access classified resources.
A user with role admin may access classified resources.
An access request for a classified resource must be approved by a security officer before the grant.

## Workflow
if the user is authorized,
  grant access to the resource for the user.
  recover from access.denied:
    Note: "access denied by provider, escalate manually",
otherwise,
  Note: "user not authorized for this resource".
Emit: "grant access pass complete".

## Anti-Patterns
- Don't bypass this skill for "just this once" requests — every ad hoc grant
  is exactly the kind of standing access `revoke stale access` exists to
  clean up later, and by then nobody remembers why it was granted.
- Don't approve a classified-resource request yourself in chat instead of
  letting the security-officer approval gate run; that gate is what makes
  the grant auditable.

## When NOT to use this skill
Route a request to `review requests` instead when a human reviewer, not a
policy evaluation, is the point of the ask — for example a backlog of
requests waiting on a reviewer's judgment rather than a clean allow/deny.
Route a request to `classify resources` first if the resource itself doesn't
have a classification yet; granting or denying access to an unclassified
resource is premature.

## Report shape
The receipt records whether access was granted, denied, or escalated for
manual review, plus the security-officer approval reference when the
resource was classified.
