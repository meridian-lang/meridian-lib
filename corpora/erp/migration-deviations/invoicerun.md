# Deviation: invoicerun.meri

- Original: `invoice_run/SKILL.md`
- Ported: `invoicerun.meri`
- Tier: 1 (near-verbatim)
- Similarity: 97%
- Lines: 37 -> 37 (+1 / -1)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L4 `When this applies`: operational-procedure - Marked or derived as applicability, but inert suppresses execution.

## Metrics
- Sections: 2/4 inert (50% inert ratio)
- Operational inert: 1
- Unclassified inert: 0
- Inert categories: operational-procedure=1, template=1
- Judgment: 0 blocks, 0 lines

### Inert section details
- L4 `When this applies`: operational-procedure — Marked or derived as applicability, but inert suppresses execution.
- L28 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/invoice_run/SKILL.md
+++ skills/invoicerun.meri
@@ -8,7 +8,7 @@
 
 # Invoice Run
 
-## When this applies
+## When this applies (( inert, role: applicability ))
 - "run invoices"
 - "billing batch"
 
```
