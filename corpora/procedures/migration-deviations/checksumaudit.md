# Deviation: checksumaudit.meri

- Original: `checksum_audit/SKILL.md`
- Ported: `checksumaudit.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 30 -> 33 (+3 / -0)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- (none)

## Metrics
- Sections inert total: 0/2 (0% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=5, structure=0, desugar=0, meaning=18

## Unified diff

```diff
--- original-skills/checksum_audit/SKILL.md
+++ skills/checksumaudit.meri
@@ -13,6 +13,9 @@
 - "audit record drift"
 
 ## Procedure
+
+### Procedure — steps
+
 fetch stale records.
 Check: at most 10 records whose status is "drifted".
 Check: at least 0 records whose status is "duplicate".
```
