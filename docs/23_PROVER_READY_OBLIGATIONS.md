# Prover-ready obligation artifacts (Wave 9B)

Meridian emits **prover-ready obligation artifacts** per skill (SEM-8-02). Each
artifact records a stable obligation id, source span, semantic scope, proof kind,
canonical English, canonical IR hash, optional proof-IR JSON, and placeholder
hooks for witness/counterexample envelopes returned by an external prover.

Formal **discharge** of obligations (Z3, Soufflé, machine-checked coherence
theorem) is **out of scope** for this repository — see
[`docs/21_OUT_OF_SCOPE.md`](21_OUT_OF_SCOPE.md). In scope here: deterministic
artifact emission, stable ids, manifest embedding, and CLI export.

---

## Artifact document

`meridian obligations <skill.meri>` writes a versioned JSON document:

| Field | Meaning |
|---|---|
| `schema_version` | Obligation artifact schema (`1`) |
| `semantics_version` | Kernel semantics oracle version (`0.3`) |
| `proof_ir_version` | Canonical proof-IR JSON dialect (`1`) |
| `identity` | Skill name, `skill_version_hash`, source file, compiler IR version |
| `obligations` | Sorted array of obligation artifacts |

Each obligation carries:

- `id` — `OBL-<sha256-prefix>` from semantic scope+kind+condition/action pattern
- `source_span` — file, line, column (authoring location)
- `scope` — stable scope (`skill`, `workflow`, `section`, `kind`)
- `kind` — `unreachability` \| `invariant` \| `coverage` \| `statistical-monitor`
- `status` — `active` (v1)
- `blocking` — whether violation is blocking at the enforcement site
- `canonical_english` — Wave 7 verbalizer output (single source of truth)
- `canonical_ir_hash` — SHA-256 of canonical semantic JSON (excludes line/wording)
- `condition_proof_ir` / `action_proof_ir` — optional JSON proof projections
- `trace_event_tags` — closed `TraceTag` set the obligation references
- `discharge` — placeholder witness/counterexample schema with `status: unknown`

The same obligations appear under `meridian_obligations` in
`*.meridian.manifest.json` when non-empty.

---

## Proof kinds

| Deontic / contract source | Proof kind |
|---|---|
| `must not invoke …` prohibition | `unreachability` |
| `… must hold` obligation | `invariant` |
| `may invoke …` permission / default-deny coverage | `coverage` |
| Monitored statistical contract assert | `statistical-monitor` |
| Regex / `since … must hold` contract assert | `invariant` |

---

## CLI

```bash
meridian obligations skill.meri
meridian obligations skill.meri --output obligations.json
meridian obligations skill.meri --summary
meridian obligations --schema
meridian explain skill.meri            # annotates [OBL-…] by default
meridian explain skill.meri --no-obligation-ids
```

Artifacts are **byte-stable** across clean builds when source is unchanged.

---

## Witness / counterexample hooks (9C evaluator)

The `discharge` block reserves shape for prover return values:

- `proved` — witness points at supporting trace slice + payload hashes
- `disproved` — counterexample points at minimal violating trace slice
- `unknown` — placeholder at emit time (no prover run)
- `unsupported` — obligation shape not yet evaluable

Wave **9C** adds the independent obligation evaluator that consumes these
artifacts against replayed traces (SEM-8-01 differential testing). Wave 9B only
defines the artifact contract and stable ids.

---

## Related docs

- [`docs/cookbook/MERIDIAN_SEMANTICS.md`](cookbook/MERIDIAN_SEMANTICS.md) §8.2
- [`docs/21_OUT_OF_SCOPE.md`](21_OUT_OF_SCOPE.md) §1 (prover discharge)
- [`docs/20_DEONTIC.md`](20_DEONTIC.md) — planned Wave 9D deontic reference
