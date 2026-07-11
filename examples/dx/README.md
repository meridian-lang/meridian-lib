# DX diagnostics example fixtures

Hand-authored `.meridian` fixtures for **developer-experience regression**
coverage: tracing, structured diagnostics, lint, and batch recovery. These live
under `examples/` alongside the other Meridian-only samples (`order_processing`,
`relations`, …) — not under `corpora/`, which is reserved for SKILL.md migration
corpora.

## Layout

```
examples/dx/
├── dx.merconfig          # minimal order/customer vocabulary
├── dx.merrules           # minimal section aliases
├── fixtures/*.meridian   # one scenario per file (see table below)
└── README.md
```

## Fixtures

| File | Expected outcome | Codes exercised |
|---|---|---|
| `match_branch_valid.meridian` | compiles; explain/drift/trace succeed | — |
| `match_branch_missing_colon.meridian` | compile error | MER1012 |
| `match_branch_duplicate_wildcard.meridian` | compile error | MER3018 |
| `lint_polite_uncertainty.meridian` | lint warnings | MER6001, MER6002 |
| `recovery_multi_error.meridian` | compile error + recovery summary | MER2001, MER6004 |

## Manual smoke

From the repo root (after `swift build --product meridian`):

```bash
CFG=examples/dx/dx.merconfig
FIX=examples/dx/fixtures

meridian compile "$FIX/match_branch_valid.meridian" --merconfig "$CFG" --namespace none
meridian compile "$FIX/match_branch_missing_colon.meridian" --merconfig "$CFG"  # MER1012
meridian lint "$FIX/lint_polite_uncertainty.meridian"                           # MER6001/6002
meridian explain "$FIX/match_branch_valid.meridian" --merconfig "$CFG" \
  --trace verbalizer --trace-file /tmp/dx-trace.log
```

## Tests

Process-level coverage lives in
`Tests/MeridianCLITests/DXCorpusFixtureTests.swift` (built `meridian` binary,
same style as `VerbalizerCLIE2ETests`).
