# Trace Storage And Export

Status: Final Wave Closure Phase G (2026-07-12). Companion to
`docs/19_TRACES_AND_TIME.md`.

---

## 1. Store implementations

| Store | Module | Persistence | Notes |
| --- | --- | --- | --- |
| `InMemoryTraceStore` | `MeridianRuntime` | No | Tests, replay fixtures |
| `JSONLTraceStore` | `MeridianRuntime` | Yes (append-only JSONL) | Default file store |
| `SQLiteTraceStore` | `MeridianRuntime` | Yes (SQLite WAL) | Indexed columns + checksum |
| `HTTPTraceStoreClient` | `MeridianRuntime` | Remote | Append/query over HTTP JSON |

All stores implement `TraceStore` with identical query ordering:

- **current run:** `ingestOrder` → `at` → `id`
- **across runs:** `at` → `ingestOrder` → `id`

---

## 2. SQLite storage schema

SQLite uses a **storage schema version** (distinct from `TraceRecord.schemaVersion`):

| Storage version | Layout |
| --- | --- |
| `1` | `trace_envelopes_v1(envelope_json, checksum)` — JSONL-compatible envelopes |
| `2` | Normalized `trace_records` table + indexes on `run_id`, `tag`, `subject`, `(at, ingest_order, id)` |

Readers support **N-1**: a v2 reader loads v1 envelope rows without migration; the first append migrates v1 → v2 in place.

Meta table: `trace_meta(key, value)` with `storage_schema_version`.

Link: system `libsqlite3` (no new SwiftPM dependency).

---

## 3. HTTP trace protocol (`meridian-trace-http/1`)

Wire format (JSON, `Content-Type: application/json`):

### Append — `POST /meridian/v1/traces/append`

```json
{
  "record": { /* TraceRecord */ },
  "checksum": "<canonical sha256 of record>"
}
```

### Query — `POST /meridian/v1/traces/query`

Request:

```json
{
  "scope": "currentRun",
  "scopeSkills": [],
  "runID": "run-1",
  "skillName": "skill",
  "windowStart": "2026-07-12T10:00:00.000Z",
  "windowEnd": null,
  "patternTags": ["emitted"],
  "patternSubject": "tool",
  "patternSubjectKey": null,
  "patternOutcome": null
}
```

Response:

```json
{ "records": [ /* TraceRecord[] */ ] }
```

Client: `HTTPTraceStoreClient` + `URLSessionHTTPTraceTransport`. Tests use an in-process `HTTPTraceTransport` mock (no external server).

---

## 4. OTLP export

`OTLPTraceExporter` maps each `TraceRecord` to an OpenTelemetry JSON span:

| Meridian field | OTLP field |
| --- | --- |
| `run` | `traceId` (deterministic hex pad) |
| `id` | `spanId` |
| `tag.rawValue` | `name` |
| `at` | `startTimeUnixNano` / `endTimeUnixNano` |
| `payloadHash`, `skillName`, `step`, … | `attributes[]` prefixed `meridian.*` |
| `outcome` | `status.code` (1=OK, 2=ERROR, 0=UNSET) |

Export endpoint: standard OTLP/HTTP JSON `POST /v1/traces` via `OTLPHTTPExporter`.

---

## 5. Signing and anchoring

`TraceBatchSigner` produces a `TraceBatchAnchor` for a run:

- **Hash-chain anchor** (default): `headHash`, `tailHash`, `recordCount` — external anchor hook documented here; no remote attestation.
- **HMAC-SHA256** (optional): sign canonical JSON of anchor fields with `CryptoKit.SymmetricKey`; verify via `TraceBatchSigner.verify`.
- **Ed25519** (optional): sign with `Curve25519.Signing.PrivateKey`; verify via `TraceBatchSigner.verify(anchor:publicKey:)`.

`=== trace ===` auto-wiring in `Runtime.Builder`:

| `store` | Required merconfig key | Auto-wired implementation |
| --- | --- | --- |
| `memory` | — | `InMemoryTraceStore` |
| `file` | optional `store path:` | `JSONLTraceStore` (temp path when omitted) |
| `sqlite` | `store path:` | `SQLiteTraceStore` |
| `http` | `store endpoint:` | `HTTPTraceStoreClient` |

Incomplete sqlite/http configuration fails closed at `build()`.

---

## 6. D12 witness envelopes and shell-hole redaction

### Witness capture (`WitnessCapture`)

Violation/assert witness envelopes (`SEM-7-05`, D12):

| Mode | Stored in `witness` JSON |
| --- | --- |
| `full` | `failingCount`, `witnessHash`, optional `subjectKey`, `body` |
| `redacted` | redacted `body` + full-content `witnessHash` |
| `hashOnly` | `failingCount`, `witnessHash`, optional `subjectKey` (no body) |
| `omitted` | `failingCount`, `witnessHash` only |

`witnessHash` is always SHA-256 of the **canonical unredacted** witness JSON.

`Runtime.recordViolation` accepts `witnessCapture`, `witnessRedactedFields`, `witnessSubjectKey`, and `failingCount`.

### Tool capture policy

`TraceCapturePolicy` adds `.omitted` (merconfig: `omitted`). Existing modes: `full`, `hash-only`, `redacted (fields)`.

### Shell-hole redaction

For `shell.run`, `ShellHoleRedaction` redacts `command`/`script`/`stdin` in invoke-start traces and `stdout`/`stderr`/`output_summary` in invoke-end traces according to capture policy (or default sensitive-key redaction when no explicit policy is set).

---

## 7. Tests

`Tests/MeridianRuntimeTests/Trace/PhaseGTraceInfrastructureTests.swift`:

- SQLite round-trip + query filters
- SQLite v1 → v2 N-1 read
- HTTP client append/query (mock transport)
- OTLP JSON payload shape
- HMAC anchor sign/verify
- D12 witness modes
- Shell-hole redaction
- `recordViolation` witness envelope on store
