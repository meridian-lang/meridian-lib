# Deviation: policyaudit.meri

- Original: `policy_audit/SKILL.md`
- Ported: `policyaudit.meri`
- Tier: 2 (light edits)
- Similarity: 75%
- Lines: 60 -> 66 (+19 / -13)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- preamble-blockquoted
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L43 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- generated_loc: 45 non-blank ported lines
- Sections inert total: 3/6 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=2, template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=45

### Inert section details
- L24 `Workflow`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L43 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L54 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/policy_audit/SKILL.md
+++ skills/policyaudit.meri
@@ -9,13 +9,13 @@
 
 # Policy Audit
 
-Not every environment needs the same depth of policy coverage. Production
-carries real user data and a real blast radius, so it needs several
-independent policies in force before an auditor will sign off; staging is
-lower stakes and one policy is enough to call it covered. This skill
-evaluates the identity provider and the audit sink against those
-per-environment thresholds and emits a receipt that states, in one line,
-whether coverage held or fell short.
+> Not every environment needs the same depth of policy coverage. Production
+> carries real user data and a real blast radius, so it needs several
+> independent policies in force before an auditor will sign off; staging is
+> lower stakes and one policy is enough to call it covered. This skill
+> evaluates the identity provider and the audit sink against those
+> per-environment thresholds and emits a receipt that states, in one line,
+> whether coverage held or fell short.
 
 ## When to invoke
 - "audit policy coverage"
@@ -29,20 +29,26 @@
 | production  | 3                  |
 | staging     | 1                  |
 
-## Workflow
-evaluate the policy for the identity provider.
-evaluate the policy for the audit sink.
-let evaluated count be the number of environments whose status is "active".
+## Workflow (( role: reference ))
 bind audit report =
   ```
   policy-audit:
   [if evaluated count is more than 0]status: covered[otherwise]status: uncovered[end if]
   environments evaluated: {{ evaluated count }}
   ```
+
+### Workflow — steps
+
+evaluate the policy for the identity provider.
+evaluate the policy for the audit sink.
+let evaluated count be the number of environments whose status is "active".
+
+### Workflow — steps 2
+
 emit governance.report with body = audit report.
 Emit: "policy audit pass complete".
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 - Don't apply the production threshold to a staging environment just
   because it's "close enough" — the coverage thresholds table exists so
   each environment is judged against its own stakes.
@@ -53,7 +59,7 @@
 ## Guarantees
 every emitted audit report contains "policy-audit".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt opens with `policy-audit:`, reports whether coverage is
 `covered` or `uncovered`, and states how many environments were evaluated in
 this pass.
```
