# Deviation: returnsprocessing.meri

- Original: `returns_processing/SKILL.md`
- Ported: `returnsprocessing.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 32 -> 32 (+5 / -5)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L22 `Report shape`: template - Template/output shape is metadata unless explicit output assertions are authored.

## Metrics
- Sections inert total: 1/3 (33% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: template=1
- Judgment: 0 blocks, 0 lines
- canonical_drift: synonym=2, structure=0, desugar=0, meaning=18

### Inert section details
- L22 `Report shape`: template — Template/output shape is metadata unless explicit output assertions are authored.

## Unified diff

```diff
--- original-skills/returns_processing/SKILL.md
+++ skills/returnsprocessing.meri
@@ -18,15 +18,15 @@
 Check: any invoices whose due date is within the last 7 days.
 
 !!! table (( decision table ))
-| lifecycle | action                |
+| lifecycle | action        |
 | --------- | ---------------------- |
-| cancelled | escalate the invoice   |
-| blocked   | escalate the invoice   |
-| *         | ship the order         |
+| cancelled | escalate the invoice  |
+| blocked  | escalate the invoice  |
+| *     | ship the order     |
 
 Publish: "returns processing pass complete".
 
-## Report shape
+## Report shape (( role: template ))
 The receipt separates cancelled and blocked returns (escalated to dunning)
 from orders cleared to ship.
 
```
