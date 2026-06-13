# Deviation: skillpack_harvest.meri

- Original: `skillpack-harvest/SKILL.md`
- Ported: `skillpack_harvest.meri`
- Tier: 1 (near-verbatim)
- Similarity: 93%
- Lines: 270 -> 270 (+18 / -18)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- preamble-blockquoted

## Metrics
- Sections: 14/15 inert (93% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/skillpack-harvest/SKILL.md
+++ skillpack_harvest.meri
@@ -31,12 +31,12 @@
 > file placement rules. This skill writes into gbrain's own tree, not the
 > brain repo's notes.
 
-This skill is the inverse of `gbrain skillpack scaffold`. Scaffold ships
-skills downstream (gbrain → host). Harvest lifts proven patterns
-upstream (host → gbrain) so they become references every other client
-can scaffold.
-
-## Contract
+> This skill is the inverse of `gbrain skillpack scaffold`. Scaffold ships
+> skills downstream (gbrain → host). Harvest lifts proven patterns
+> upstream (host → gbrain) so they become references every other client
+> can scaffold.
+
+## Contract (( inert, role: invariants ))
 
 A harvest is "properly done" when:
 
@@ -71,7 +71,7 @@
 a list of files written. JSON mode (`--json`) returns the full
 `HarvestResult` shape for machine consumption.
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - **Skipping the dry-run.** Always preview first. Files land in
   gbrain's working tree; cleanup is a `git checkout` away, but you
@@ -89,7 +89,7 @@
 - **Harvesting batch (multiple skills at once).** Not supported, and
   for good reason — the editorial review per skill is real work.
 
-## When to invoke
+## When to invoke (( inert, role: applicability ))
 
 - The user developed a skill in their host fork (Wintermute, Neuromancer,
   Zion, etc.) and wants other gbrain clients to be able to use it
@@ -101,7 +101,7 @@
 - The skill references private content that can't be generalized
 - The user just wants to share a one-off draft (use a gist instead)
 
-## Preconditions
+## Preconditions (( inert ))
 
 Before running this skill, confirm:
 
@@ -117,7 +117,7 @@
 
 ## Workflow
 
-### Phase 1 — Plan
+### Phase 1 — Plan (( inert, role: procedure ))
 
 Ask the user:
 - What slug should the harvested skill have? (Slugs must be kebab-case,
@@ -127,7 +127,7 @@
 - Should paired source files come along? (Check the host SKILL.md's
   frontmatter `sources:` array.)
 
-### Phase 2 — Dry-run + privacy-lint preview
+### Phase 2 — Dry-run + privacy-lint preview (( inert, role: procedure ))
 
 Run the CLI with `--dry-run`:
 
@@ -146,7 +146,7 @@
 land. Spot-check the SKILL.md and any paired source for things the
 linter might miss (proper nouns, internal project names, etc.).
 
-### Phase 3 — Genericization checklist (the editorial pass)
+### Phase 3 — Genericization checklist (the editorial pass) (( inert, role: procedure ))
 
 Before running the real harvest, walk the host's `skills/<slug>/`
 files and apply this checklist. If anything matches, edit the host
@@ -186,7 +186,7 @@
      same private-pattern leaks. Comments are the most common
      hiding spot.
 
-### Phase 4 — Real harvest
+### Phase 4 — Real harvest (( inert, role: procedure ))
 
 Once Phase 3 is complete, run the real harvest:
 
@@ -209,7 +209,7 @@
   use a different slug, or pass `--overwrite-local` if you really
   mean to replace.
 
-### Phase 5 — Verify in gbrain
+### Phase 5 — Verify in gbrain (( inert, role: procedure ))
 
 After a successful harvest:
 
@@ -222,14 +222,14 @@
 5. Commit the additions in gbrain (do NOT commit any leftover files
    in the host repo — harvest is a copy, not a move).
 
-### Phase 6 — Downstream announcement (optional)
+### Phase 6 — Downstream announcement (optional) (( inert, role: procedure ))
 
 If other gbrain clients should pick up the new skill:
 - Note it in `CHANGELOG.md` under "Skills added" for the next release
 - Tag the user / contributor in the PR if the skill came from
   someone outside the core team
 
-## Bypass: `--no-lint`
+## Bypass: `--no-lint` (( inert ))
 
 The privacy linter is the safety net. The editorial pass is the
 primary defense. If you've completed Phase 3 thoroughly and the
@@ -247,7 +247,7 @@
 default-on lint is that real names occasionally slip through the
 editorial pass.
 
-## What harvest does NOT do
+## What harvest does NOT do (( inert ))
 
 - It does NOT move files (it copies). The host's `skills/<slug>/`
   stays in place.
@@ -258,7 +258,7 @@
 - It does NOT support `--all` (no batch harvest). One skill at a
   time keeps the editorial review tractable.
 
-## Files this skill touches
+## Files this skill touches (( inert ))
 
 - gbrain's `skills/<slug>/` — every file in the host skill dir
   (copy)
```
