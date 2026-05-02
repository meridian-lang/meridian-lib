# `.ai/brainstorm-done/`

Append-only archive of design plans whose implementation has shipped. Each
plan is preserved here so that opaque references (`SkillMD-D17`, `SkillMD-D22`,
`B6`, etc.) in tests, code comments, `IMPLEMENTATION_LOG.md`, and `AGENTS.md`
remain meaningful long after the original planning conversation has been
discarded.

> **D-tag prefix convention.** Plans archived here own a private namespace —
> their D-tags are prefixed with the plan's slug (e.g. `SkillMD-D17` for the
> SKILL.md expressiveness plan). The bare `D1`–`D30` numbering is reserved for
> the architectural decision log in
> [`meridian-handoff/docs/11_DECISIONS.md`](../../meridian-handoff/docs/11_DECISIONS.md).
> When introducing a new plan in this folder, pick a unique prefix and use it
> consistently in code, tests, and log entries.

## Index

| File | Topic | Implemented |
|------|-------|-------------|
| [`skill_md_expressiveness_d1_d28.md`](skill_md_expressiveness_d1_d28.md) | SKILL.md expressiveness three-tier model: deterministic surface (`SkillMD-D1`–`SkillMD-D11`), prose plan + autonomy (`SkillMD-D11a`–`SkillMD-D20`), test infra (`SkillMD-D21`–`SkillMD-D22`), idioms + Inform rulebooks (`SkillMD-D23`–`SkillMD-D23a`), diagnostics (`SkillMD-D24`–`SkillMD-D26`), resource limits + replay (`SkillMD-D27`–`SkillMD-D28`). Disambiguates from the architectural decision log. | 2026-04-30 → 2026-05-01 |

## Conventions

- One file per plan.
- Filename slug should match the canonical D-/B-tag range it documents
  (e.g. `skill_md_expressiveness_d1_d28.md`).
- D-tags from a plan archived here MUST be prefixed in code, tests, and log
  entries to avoid collision with the architectural decision log
  (`meridian-handoff/docs/11_DECISIONS.md`). The SKILL.md plan uses the
  `SkillMD-` prefix; future plans should adopt similar plan-specific prefixes.
- Entries are append-only. Revisions add a new section at the bottom rather
  than editing existing content, so future readers can trust the historical
  record.
- If a plan introduces new D-/B-tags, mention them in this index so they can
  be located by string-search.
