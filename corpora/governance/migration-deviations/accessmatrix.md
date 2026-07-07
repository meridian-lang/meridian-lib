# Deviation: accessmatrix.meri

- Original: `access_matrix/SKILL.md`
- Ported: `accessmatrix.meri`
- Tier: 2 (light edits)
- Similarity: 77%
- Lines: 62 -> 68 (+18 / -12)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L45 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L56 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 3/6 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L26 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L45 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L56 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/access_matrix/SKILL.md
+++ skills/accessmatrix.meri
@@ -9,13 +9,13 @@
 
 # Access Matrix
 
-Every access-governance audit eventually asks the same question: "who can
-see what, and does that match the policy we think we have?" Rather than
-answer that question by reading through every rule in `governance.merrules`,
-this skill renders a single role-by-classification table and pairs it with a
-count of the pending requests waiting behind it. The table is the
-policy-as-declared; the pending count is a signal for whether the matrix is
-stale the moment it's published.
+> Every access-governance audit eventually asks the same question: "who can
+> see what, and does that match the policy we think we have?" Rather than
+> answer that question by reading through every rule in `governance.merrules`,
+> this skill renders a single role-by-classification table and pairs it with a
+> count of the pending requests waiting behind it. The table is the
+> policy-as-declared; the pending count is a signal for whether the matrix is
+> stale the moment it's published.
 
 ## When to invoke
 - "render access matrix"
@@ -31,20 +31,26 @@
 | user  | classified      | deny    |
 | user  | public          | allow   |
 
-## Workflow
-fetch pending access requests.
-let classified count be the number of access requests whose status is "pending".
+## Workflow (( role: reference ))
 bind matrix report =
   ```
   access-matrix:
   [if classified count is more than 0]status: reviewed[otherwise]status: empty[end if]
   pending requests: {{ classified count }}
   ```
+
+### Workflow — steps
+
+fetch pending access requests.
+let classified count be the number of access requests whose status is "pending".
+
+### Workflow — steps 2
+
 emit governance.audit with body = matrix report.
 - [ ] the classified count is at least 0
 Emit: "access matrix pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't hand-edit the rendered matrix to "fix" a row that looks wrong.
   If the outcome column disagrees with what policy actually grants, the fix
   belongs in the rule, not in the report.
@@ -55,7 +61,7 @@
 ## Guarantees
 every emitted matrix report contains "access-matrix".
 
-## Report shape
+## Report shape (( role: template ))
 The audit artifact opens with `access-matrix:`, states whether the pending
 queue has been reviewed or is empty, and reports the pending-request count
 at render time.
```
