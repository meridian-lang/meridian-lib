# Trace Storage And Export

Status: Final Wave Closure Phase G (2026-07-12). Companion to
`docs/19_TRACES_AND_TIME.md`.

---

## 1. Store implementations

| Store | Module | Persistence | Notes |
| --- | --- | --- | --- |
| `InMemoryTraceStore` | `MeridianRuntime` | No | Tests, replay fixtures |
| `JSONLTraceStore` | `MeridianRuntime` | Yes (append-only JSONL) | Default file store |

All stores implement `TraceStore` with identical query ordering:

- **current run:** `ingestOrder` → `at` → `id`
- **across runs:** `at` → `ingestOrder` → `id`

`TraceRecord.currentSchemaVersion` is the single supported schema; readers
ignore unknown JSON keys, so records written by older layouts still load.

---

## 2. `=== trace ===` auto-wiring

`Runtime.Builder` auto-wires a store from the compiled
`RuntimeTraceConfiguration`:

| `store` | Required merconfig key | Auto-wired implementation |
| --- | --- | --- |
| `memory` | — | `InMemoryTraceStore` |
| `file` | optional `store path:` | `JSONLTraceStore` (temp path when omitted) |

---

## 3. Tool capture policy

`TraceCapturePolicy` modes: `full`, `hash-only`, `redacted (fields)`, and
`omitted` (merconfig: `omitted`).

### Shell-hole redaction

For `shell.run`, `ShellHoleRedaction` redacts `command`/`script`/`stdin` in invoke-start traces and `stdout`/`stderr`/`output_summary` in invoke-end traces according to capture policy (or default sensitive-key redaction when no explicit policy is set).

---

## 4. Tests

`Tests/MeridianRuntimeTests/Trace/PhaseGTraceInfrastructureTests.swift`:

- Shell-hole redaction
- `recordViolation` emits a violated record on store
