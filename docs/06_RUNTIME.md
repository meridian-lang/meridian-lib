# Meridian — Runtime API

`MeridianRuntime` (in `Sources/MeridianRuntime/`) is the library that generated
Swift code imports and depends on at runtime. It provides:

1. `MeridianWorkflow` protocol — what generated structs conform to
2. `Runtime` actor — the observable execution context
3. `Value` enum — type-erased runtime value
4. `State` struct — local mutable store inside a workflow run
5. `MeridianComparison` — comparison helpers for `Value?` types
6. `WorkflowResult` — what `run()` returns
7. `TraceRecord` + `EventKind` — the single runtime record type (one record per emission; `kind` plus the projected `tag`)
8. `Observer` protocol + implementations — record sinks (`record(_ record: TraceRecord)` is `async throws`; failures abort under fail-closed policy)
9. `ToolRegistry` — tool dispatch (closure, subprocess, HTTP, MCP)
10. `InstanceRegistry` — named instance lookup
11. `Checkpointer` — checkpoint persistence (in-memory + filesystem-backed)
12. `WaitCondition` — wait semantics (duration, signal, approval, event, choice)
13. `MeridianRuntimeError` — typed error envelope (includes `observerFailure` / `traceStoreFailure`)
14. `TraceStore` + `TraceRecord` — semantic witnessing; `TraceConfiguration.default.storeFailurePolicy` is `.failClosed`

---

## `MeridianWorkflow` protocol

```swift
public protocol MeridianWorkflow: Sendable {
    var runtime: Runtime { get }
    func run() async throws -> WorkflowResult
}
```

Generated structs conform to this protocol. There is no `associatedtype`.

---

## `WorkflowResult`

```swift
public struct WorkflowResult: Sendable {
    public let reason: String?
    public let durationMS: Double      // Note: Double, not Int
    public let eventCount: Int
    public let bindings: [String: Value]?
}
```

The value returned by `run()`. For workflow-calls-within-workflow the result
is discarded with `_ = try await SubWorkflow(…).run()`.

---

## `Runtime` actor

```swift
public actor Runtime {
    public nonisolated let runID: String
    public nonisolated let clock: any Clock

    public init(
        toolRegistry: ToolRegistry,
        instanceRegistry: InstanceRegistry = .empty,
        observer: any Observer = JSONLObserver.stdout,
        traceStore: (any TraceStore)? = nil,
        checkpointer: any Checkpointer = InMemoryCheckpointer(),
        clock: any Clock = SystemClock(),
        runID: String = UUID().uuidString,
        parentRunID: String? = nil,
        parentSequence: Int? = nil,
        maxNestingDepth: Int = 32,
        traceConfiguration: TraceConfiguration = .default,
        traceSkillIdentity: TraceSkillIdentity = .unknown
    )
}

public protocol Observer: Sendable {
    func record(_ record: TraceRecord) async throws
}
```

CLI/test drivers wire an `InMemoryTraceStore` or `JSONLTraceStore` whenever a
workflow exposes `runtimeTraceConfiguration`. `Observer.record` failures and
trace-store append failures abort the run under `.failClosed` (the default);
explicit `.failOpen` emits operational diagnostics and a degradation marker.

`Runtime.Builder` is the fluent alternative to `Runtime.init`. `build()` is
`throws` (e.g. when auto-wiring a `.file` `JSONLTraceStore` fails). Calling
`setRuntimeTraceConfiguration` arms auto-wiring: on `build()`, the builder
creates an `InMemoryTraceStore` for `.memory` or a temp-directory
`JSONLTraceStore` for `.file` when no explicit store was set via
`setTraceStore`. An explicit non-nil `setTraceStore` disables auto-wiring.

### Methods called by generated code

```swift
// Tool invocation — dispatches through ToolRegistry, emits invoke.start + invoke.end
public func invoke(
    tool toolID: String,
    args: [String: Value],
    sourceRange: SourceRange? = nil
) async throws -> Value

// Domain event (strict) — throws on observer failure
public func emit(
    event eventID: String,
    payload: [String: Value],
    sourceRange: SourceRange? = nil
) async throws

// Domain event (lenient) — logs failure, does not throw
public func emitLenient(
    event eventID: String,
    payload: [String: Value],
    sourceRange: SourceRange? = nil
) async

// Suspend for a wait condition (see WaitCondition section below)
public func wait(
    _ condition: WaitCondition,
    timeout: Duration? = nil,
    sourceRange: SourceRange? = nil
) async throws

// Assertion — emits assert.passed on success; emits assert.failed + throws on failure
public func assert(
    _ condition: Bool,
    message: String,
    sourceRange: SourceRange? = nil
) async throws

// Checkpoint state (commit label in source)
public func checkpoint(
    label: String? = nil,
    state: StateSnapshot,
    sourceRange: SourceRange? = nil
) async throws

// Mark workflow complete — emit workflow.completed event
public func complete(reason: String?, sourceRange: SourceRange? = nil) async

// Resolve a named instance handle
public func instance(_ name: String) async throws -> InstanceHandle

// Diagnostics — NOT async; nonisolated
public func elapsedMS() -> Double
public func eventCount() -> Int
```

**Important:** `elapsedMS()` and `eventCount()` are not `async`. Generated
code calls them without `await`.

### Resume-related methods

```swift
// Read-only lookup: returns the latest checkpoint for runID without storing it.
public func resume(runID: String) async throws -> ResumeContext

// Store the resume context on the actor so generated run() can consume it.
// Emits workflow.resumed event.
@discardableResult
public func prepareResume(runID: String) async throws -> ResumeContext

// Return the stored context without consuming it.
public func activeResumeContext() async -> ResumeContext?

// Return AND clear the stored context (called once at the top of generated run()).
public func consumeResumeContext() async -> ResumeContext?

// Clear without returning.
public func clearResumeContext() async
```

### Wait delivery methods

External callers (event loops, human approval webhooks, test harnesses) use
these to unblock waiting workflows:

```swift
// Unblock any workflow waiting for signal `name`.
public func deliverSignal(_ name: String) async

// Unblock a workflow waiting for approval of `subject` by `role`.
// .approved resumes normally; .denied throws MeridianRuntimeError.approvalDenied.
public func deliverApproval(
    of subject: Value,
    by role: String,
    verdict: RuntimeApprovalVerdict
) async

// Unblock any event waiter whose predicate matches.
// Also triggered automatically when emit(event:) fires a matching event.
public func deliverEvent(id: String, payload: [String: Value] = [:]) async
```

---

## `WaitCondition`

```swift
public enum WaitCondition: Sendable {
    case duration(Duration)
    case signal(String)
    case approval(of: Value, by: RoleRef)
    case event(String, matching: (@Sendable (TraceRecord) -> Bool)?)
    case choice(prompt: String, options: [String])
}
```

All five variants are implemented end-to-end:

| Variant | Semantics |
|---|---|
| `.duration` | Suspends via `Clock.sleep`; honours the `timeout:` parameter |
| `.signal` | Blocks until `deliverSignal(_:)` is called with the matching name. Signals delivered while no waiter exists are dropped. |
| `.approval` | Blocks until `deliverApproval(of:by:verdict:)` fires. `.approved` resumes normally; `.denied` throws `MeridianRuntimeError.approvalDenied`. |
| `.event` | Blocks until `deliverEvent(id:payload:)` or any `emit(event:)` call fires a record matching the event ID and optional predicate. `nil` predicate = accept any record with matching ID. |
| `.choice` | Blocks until `deliverChoice(_:)` supplies a selected option for a choice gate. |

**Timeout note:** The `timeout:` parameter is enforced for all wait variants in
Final Wave Phase F. When the timeout elapses first, `wait` throws
`MeridianRuntimeError.timeout`, catchable via `recover from wait.timeout:`.
Duration waits still honour the lesser of the requested sleep and the timeout
cap (unchanged).

### Commit and recover (honest semantics)

| Surface | Runtime behaviour | Not automatic |
|---|---|---|
| `commit.` / `commit with label "…".` | `checkpoint(label:state:)` persists a `StateSnapshot` via the configured `Checkpointer` and emits a `commit` trace event | No distributed transaction rollback |
| `recover from …:` | Typed `do/catch` around the attached statement; `recordRecoverEngaged` witnesses the handler arm | No compensation/saga unless authored in the handler body |
| `wait … recovering on timeout:` | Desugars to `recover from wait.timeout:` wrapping the wait | — |

Compensation tokens and external rollback remain author-owned: Meridian records
checkpoints and typed recovery boundaries in the trace, but does not infer
multi-resource rollback from `commit` alone.

`RuntimeApprovalVerdict` (2 cases, distinct from the domain `ApprovalVerdict`):

```swift
public enum RuntimeApprovalVerdict: String, Codable, Sendable {
    case approved
    case denied
}
```

The 3-case domain `ApprovalVerdict` (adding `.deferred`) is generated from
vocabulary. They are distinct types.

---

## Kind protocols (`MeridianKind` and friends)

Defined in `Sources/MeridianRuntime/Domain/Thing.swift`. These are the
runtime-side base protocols that every generated `<KindName>Kind` protocol
composes. They give the type system a way to talk about a kind's *role* —
"this is something that occurred", "this is an actor identity" — without
forcing every kind through one structural baseline.

```swift
public protocol MeridianKind: Hashable, Codable, Sendable {
    var id: String { get }
}

public protocol MeridianThing:   MeridianKind {}
public protocol MeridianEvent:   MeridianKind {}
public protocol MeridianAction:  MeridianKind {}
public protocol MeridianTool:    MeridianKind {}
public protocol MeridianSystem:  MeridianKind {}
public protocol MeridianIntegration: MeridianKind {}
public protocol MeridianArtifact: MeridianKind {}
public protocol MeridianService: MeridianKind {}
public protocol MeridianAgent:   MeridianKind {}
public protocol MeridianModel:   MeridianKind {}
public protocol MeridianDataset: MeridianKind {}
public protocol MeridianStorage: MeridianKind {}
public protocol MeridianCredential: MeridianKind {}
public protocol MeridianPolicy:  MeridianKind {}
public protocol MeridianEnvironment: MeridianKind {}
public protocol MeridianResource: MeridianKind {}
public protocol MeridianMetric:  MeridianKind {}
public protocol MeridianMemory:  MeridianKind {}
public protocol MeridianProcess: MeridianKind {}
public protocol MeridianMessage: MeridianKind {}
public protocol MeridianSignal:  MeridianKind {}
public protocol MeridianFact:    MeridianKind {}
public protocol MeridianRole:    MeridianKind {}
public protocol MeridianVerdict: MeridianKind {}
```

The semantic markers are intentionally empty. The discriminator is the
*name* of the protocol; the `Hashable + Codable + Sendable + id`
requirements live on `MeridianKind` so `State`'s opaque traversal can
JSON-round-trip dotted lookups (`customer.email`).

The `Meridian` prefix is mandatory. Several of the bare names already
resolve to other types in scope:

- `EventKind` is the public emission-discriminator enum in `MeridianRuntime`
  (the `kind` field on `TraceRecord`, see `## TraceRecord and EventKind` below).
- `Process` is a Foundation class.
- `Tool` is used as a discriminating noun in many runtime APIs.

Prefixing every base uniformly avoids surprise for vocabulary authors and
keeps generated code unambiguous.

### Mapping from vocabulary

`A foo is a kind of <base>.` selects the parent at codegen time:

| Vocabulary phrase | Generated parent |
|---|---|
| `kind of thing` | `MeridianThing` |
| `kind of event` | `MeridianEvent` |
| `kind of action` | `MeridianAction` |
| `kind of tool` | `MeridianTool` |
| `kind of system` | `MeridianSystem` |
| `kind of integration` | `MeridianIntegration` |
| `kind of artifact` | `MeridianArtifact` |
| `kind of service` | `MeridianService` |
| `kind of agent` | `MeridianAgent` |
| `kind of model` | `MeridianModel` |
| `kind of dataset` | `MeridianDataset` |
| `kind of storage` | `MeridianStorage` |
| `kind of credential` | `MeridianCredential` |
| `kind of policy` | `MeridianPolicy` |
| `kind of environment` | `MeridianEnvironment` |
| `kind of resource` | `MeridianResource` |
| `kind of metric` | `MeridianMetric` |
| `kind of memory` | `MeridianMemory` |
| `kind of process` | `MeridianProcess` |
| `kind of message` | `MeridianMessage` |
| `kind of signal` | `MeridianSignal` |
| `kind of fact` | `MeridianFact` |
| `kind of role` | `MeridianRole` |
| `kind of verdict` | `MeridianVerdict` |
| `kind of <DeclaredKind>` | `<DeclaredKind>Kind` (chains) |
| `kind of <Scalar>` | `typealias` to the Swift scalar — no protocol/struct |

A leaf kind with no own properties and no descendants gets a struct only
(no `<KindName>Kind` protocol). The struct conforms directly to the parent
protocol; the empty kind protocol would add nothing.

See [`05_CODEGEN.md`](05_CODEGEN.md) §"Domain types (`DomainEmitter`)" for
the per-path output, and [`03_LANGUAGE_QUICK_REFERENCE.md`](03_LANGUAGE_QUICK_REFERENCE.md)
§"Kind declarations" for authoring guidance on which base to pick.

### Using kind protocols in host code

Host code can constrain APIs to "anything that's a Role" or "anything that's
an Event" without naming individual user kinds:

```swift
func dispatch<E: MeridianEvent>(_ event: E) async throws { … }
func roleOf<R: MeridianRole>(_ actor: R) -> String { actor.id }
```

Generated workflow init signatures still take the concrete struct type
(`Order`, `Reviewer`, …), not the protocol — workflows are sealed at
compile time so the concrete type is always available there.

---

## `Value` enum

```swift
public enum Value: Sendable {
    case string(String)
    case number(Decimal)
    case boolean(Bool)
    case money(Money)
    case duration(Duration)
    case date(Date)
    case dateTime(Date)                        // separate from .date
    case enumValue(String, kind: String)       // typed enum from vocabulary
    case record([String: Value])
    case list([Value])
    case reference(String)                     // opaque reference ID
    case null
    case opaque(AnyHashableSendable)           // custom Swift types

    public static let unit = Value.null
}
```

`AnyHashableSendable` is a type-erasing box (`@unchecked Sendable, Hashable`)
that wraps any `Hashable & Sendable` value for `.opaque`. It has two
initialisers:

```swift
public struct AnyHashableSendable: @unchecked Sendable, Hashable {
    public init<T: Hashable & Sendable>(_ value: T)
    // Captures Encodable conformance at construction time for state traversal.
    public init<T: Hashable & Sendable & Encodable>(_ value: T)

    public func unwrap<T>(as type: T.Type) -> T?
    @discardableResult
    public func encodeIfEncodable(to encoder: Encoder) throws -> Bool
}
```

### `Value.from(_:)` bridge (`ValueCoercion.swift`)

```swift
extension Value {
    public static func from(_ s: String) -> Value
    public static func from(_ n: Decimal) -> Value
    public static func from(_ m: Money) -> Value
    public static func from(_ d: Duration) -> Value
    public static func from(_ dt: Date) -> Value
    public static func from(_ b: Bool) -> Value
    public static func from<T: Hashable & Sendable>(_ v: T) -> Value

    // Returns .list contents, or nil. Used by iterate codegen.
    public var asList: [Value]? { get }
}
```

---

## `State` struct

```swift
public struct State: Sendable {
    public init()

    public mutating func bind(_ key: String, _ value: Value)
    public mutating func bind<T: Hashable & Sendable>(_ key: String, _ value: T)
    // Captures Encodable so state.get("order.totalAmount") can JSON-traverse through it.
    public mutating func bind<T: Hashable & Sendable & Encodable>(_ key: String, _ value: T)

    public mutating func rebind(_ key: String, _ value: Value)

    // Read by dot-separated key path. Opaque Encodable values are traversed via Codable.
    public func get(_ keyPath: String) -> Value?

    // Restore all bindings from a checkpoint snapshot.
    public mutating func restore(from snapshot: StateSnapshot)

    public func snapshot() -> StateSnapshot
}
```

Keys are dot-separated paths (`"order"`, `"order.id"`, `"order.totalAmount"`,
`"result"`). Bind names are camelCased from multi-word source names
(`"validation result"` → `"validationResult"`). Property segments inside
dotted paths are camelCase too, aligning with `Codable`'s default key encoding.

### `StateSnapshot` (for checkpointing)

```swift
public struct StateSnapshot: Codable, Sendable {
    public let bindings: [String: AnyCodable]
    public var asValues: [String: Value]    // convenience accessor
}
```

---

## `MeridianComparison`

```swift
public enum MeridianComparison {
    public static func isWithin(_ lhs: Value?, _ rhs: Value?) -> Bool
    public static func eq(_ lhs: Value?, _ rhs: Value?) -> Bool
    public static func neq(_ lhs: Value?, _ rhs: Value?) -> Bool
    public static func lt(_ lhs: Value?, _ rhs: Value?) -> Bool
    public static func le(_ lhs: Value?, _ rhs: Value?) -> Bool
    public static func gt(_ lhs: Value?, _ rhs: Value?) -> Bool
    public static func ge(_ lhs: Value?, _ rhs: Value?) -> Bool

    // NumericConvertible overloads (T: Decimal | Int | Double | Money | Duration)
    public static func lt<T: NumericConvertible>(_ lhs: Value?, _ rhs: T) -> Bool
    // … all 6 ops × 3 overload shapes
}
```

The internal `numeric(_:)` extractor recognises:

- `.number(n)` → `n`
- `.money(m)` → `m.amount`
- `.duration(d)` → `Decimal(d.components.seconds)`
- `.string(s)` → `Decimal(string: s)` (best-effort)
- `.record(["amount": .number(n), …])` → `n` (Codable-round-tripped `Money`)
- `.record(["seconds": .number(n), …])` → `n` (Codable-round-tripped `Duration`)

---

## `TraceRecord` and `EventKind`

There is exactly one runtime record type. `TraceRecord` carries the emission
(`kind`, payload, source range, parent correlation) *and* the semantic
projection (`tag`, `subject`, `outcome`, `operationalDetail`, `payloadHash`)
derived from `kind` by the kind table in `Trace/TraceRecord.swift`.

```swift
public struct TraceRecord: Sendable {
    public let schemaVersion: Int
    public let id: String
    public let at: Date
    public let ingestOrder: Int
    public let run: String
    public let step: String
    public let skillName: String
    public let skillVersionHash: String
    public let tag: TraceTag
    public let subject: String?
    public let subjectKey: String?
    public let payload: [String: Value]?
    public let payloadHash: String
    public let outcome: TraceOutcome?
    public let operationalDetail: String?
    public let kind: EventKind
    public let sourceRange: SourceRange?
    public let parentRunID: String?
    public let parentSequence: Int?
}
```

`Runtime` builds the record once per emission (via
`TraceRecord(kind:at:run:ingestOrder:skillName:skillVersionHash:id:…)`),
appends it to the configured `TraceStore` (when any), then hands the *same*
record to its `Observer`. `JSONLObserver` writes the golden JSONL shape from
it (`ts`/`run_id`/`seq`/`kind`/`payload`/`source`/`parent_run_id`/`parent_seq`).
`EventKind` decodes as `.emit` when a record has no kind, and older JSONL files
that still carry the `legacyKind` key keep loading.

```swift
public enum EventKind: String, Codable, Sendable {
    case workflowStarted    = "workflow.started"
    case workflowCompleted  = "workflow.completed"
    case workflowFailed     = "workflow.failed"
    case workflowCancelled  = "workflow.cancelled"
    case workflowSuspended  = "workflow.suspended"
    case workflowResumed    = "workflow.resumed"
    case bind
    case invokeStart        = "invoke.start"
    case invokeEnd          = "invoke.end"
    case invokeError        = "invoke.error"
    case planStart          = "plan.start"
    case planEnd            = "plan.end"
    case planError          = "plan.error"
    case planRejected       = "plan.rejected"
    case autonomyStart      = "autonomy.start"
    case autonomyStep       = "autonomy.step"
    case autonomyEnd        = "autonomy.end"
    case branchTaken        = "branch.taken"
    case branchEnded        = "branch.end"
    case iterateStart       = "iterate.start"
    case iterateIteration   = "iterate.iteration"
    case iterateEnd         = "iterate.end"
    case assertPassed       = "assert.passed"
    case assertFailed       = "assert.failed"
    case emit
    case emitError          = "emit.error"
    case waitStart          = "wait.start"
    case waitResume         = "wait.resume"
    case commit
    case recoverEngaged     = "recover.engaged"
    case violated
}
```

31 event kinds across all IR primitives, planning/autonomy, lifecycle, and
deontic-violation events.

---

## `Observer` protocol

```swift
public protocol Observer: Sendable {
    func record(_ record: TraceRecord) async throws
}
```

### Provided implementations

| Type | Description |
|---|---|
| `JSONLObserver` | Writes JSONL to stdout or a file. Default: `JSONLObserver.stdout` |
| `InMemoryObserver` | Actor; accumulates records in `events: [TraceRecord]`. Use in tests. |
| `CompositeObserver` | Fan-out to multiple observers. |

`TraceStore` refines `Observer`: a store can be installed as the runtime's
observer and its default `record(_:)` appends.

`JSONLObserver` follows the golden JSONL shape — fields like `tool`, `parent_run_id`,
`source` are promoted to top-level per event kind.

---

## `ToolRegistry`

`ToolRegistry` maps tool IDs to dispatch instructions.

```swift
public enum ToolKind: Sendable {
    case closure(@Sendable ([String: Value]) async throws -> Value)
    case subprocess(SubprocessSpec)
    case http(HTTPSpec)
    case mcp(MCPSpec)
}
```

### Registration

`ToolRegistry` uses a mutable registration API:

```swift
let registry = ToolRegistry()
await registry.register(tool: "validateOrder", .closure { args in
    // … return Value
    return .record(["verdict": .string("valid")])
})
await registry.register(tool: "chargePayment", .closure { args in … })
```

Then passed to `Runtime.init(toolRegistry:)`.

### Blueprint built-ins

`MeridianTools.registerBuiltins()` registers all Blueprint built-in tools:

```swift
let registry = ToolRegistry()
await registry.registerBuiltins()   // http.*, file.*, json.*, regex.*, shell.run, mcp.call, etc.
await registry.register(tool: "validateOrder", .closure { … })  // domain tools alongside
```

See [10_BUILTIN_TOOLS.md](10_BUILTIN_TOOLS.md) for the full built-in catalog.

### Subprocess dispatch

`SubprocessSpec` defines a binary + argument template:

```swift
public struct SubprocessSpec: Sendable {
    public let binary: String
    public let argTemplate: [String]   // "{command}" → replaced from args["command"]
    public let timeout: Duration?      // nil = no timeout
    public let stdin: String?          // optional stdin text
}
```

`shell.run` registers as `.subprocess(SubprocessSpec(binary: "/bin/sh", argTemplate: ["-c", "{command}"]))`.

### HTTP dispatch

`HTTPSpec` defines a URL template + method:

```swift
public struct HTTPSpec: Sendable {
    public let url: String           // "{url}" → replaced from args["url"]
    public let method: String        // "GET", "POST", "PUT", "DELETE"
    public let timeout: Duration?
}
```

The dispatcher substitutes `{key}` placeholders in the URL from `args`, sends
the request, and returns `.record(["status": .number(…), "body": .string(…), "headers": .record(…)])`.

### MCP dispatch

`MCPSpec` carries transport configuration. The actual transport is provided by a
replaceable `MCPClient` protocol:

```swift
public protocol MCPClient: Sendable {
    func call(method: String, params: [String: Value]) async throws -> Value
}
```

Two built-in transports:
- **HTTP JSON-RPC** — sends a `POST` with `{"jsonrpc":"2.0","method":…,"params":…}` to an endpoint.
- **Subprocess stdio** — launches a process, writes JSON-RPC over stdin, reads from stdout.

Replace the client by registering a custom `MCPClient` before running:

```swift
registry.mcpClient = MyCustomMCPClient()
```

---

## `InstanceRegistry`

Named instances from `.merconfig` are registered in `InstanceRegistry` at
startup. Each instance is an `InstanceHandle`:

```swift
public struct InstanceHandle: Sendable, Hashable {
    public let kind: String
    public let name: String
    public let properties: [String: PropertyValue]
}

public enum PropertyValue: Sendable, Hashable {
    case literal(Value)
    case envVar(String)    // resolved lazily from ProcessInfo at call time
}
```

`InstanceRegistry.Builder` is the builder:

```swift
let instances = InstanceRegistry.Builder()
    .register(kind: "mailer_server", name: "primary mailer", properties: [
        "host": .envVar("SMTP_HOST"),
        "port": .literal(.number(587)),
        "auth_type": .literal(.string("tls")),
    ])
    .build()
```

---

## `Checkpointer` + `Checkpoint` + `ResumeContext`

```swift
public struct Checkpoint: Codable, Sendable {
    public let runID: String
    public let sequence: Int
    public let timestamp: Date
    public let label: String?
    public let stateSnapshot: StateSnapshot
    public let sourceRange: SourceRange?
}

public protocol Checkpointer: Sendable {
    func write(_ checkpoint: Checkpoint) async throws
    func readAll(forRun runID: String) async throws -> [Checkpoint]
    func latest(forRun runID: String) async throws -> Checkpoint?
    func clear(forRun runID: String) async throws
}
```

Two implementations ship:

| Type | Backing | Use case |
|---|---|---|
| `InMemoryCheckpointer` | dict keyed by runID | tests, ephemeral runs |
| `FilesystemCheckpointer` | one JSON file per checkpoint under `<root>/<runID>/<NNNNNNNNN>.json` | durable runs, resume across process restarts |

`FilesystemCheckpointer` writes are durable:
- Writes to a `.tmp` sibling first.
- Calls `fsync` on the temp file.
- Renames atomically to the target.
- Calls `fsync` on the parent directory to flush the directory entry.
- Holds a per-run POSIX advisory lock via `lockf(3)` (`F_LOCK`/`F_ULOCK`) on a
  `<runDir>/.lock` file, preventing multi-process concurrent writes for the same run ID.

The default convenience `init()` lands checkpoints under
`~/Library/Caches/meridian-checkpoints/`; an `init(rootURL:)` form is
available for tests / custom roots.

`ResumeContext`:

```swift
public struct ResumeContext: Sendable {
    public let runID: String
    public let lastCheckpointLabel: String?
    public let restoredState: StateSnapshot
}
```

Typical resume flow:

```swift
// Before calling run(), prepare the context on the actor.
try await runtime.prepareResume(runID: "my-run-001")

// Generated run() calls consumeResumeContext() at startup,
// restores state, and skips already-checkpointed steps.
let result = try await ProcessOrder(runtime: runtime, order: order, customer: customer).run()
```

---

## `SourceRange`

```swift
public struct SourceRange: Codable, Sendable, Hashable {
    public let file: String
    public let startLine: Int
    public let startColumn: Int
    public let endLine: Int
    public let endColumn: Int

    // Convenience single-location init
    public init(file: String, line: Int, column: Int)
}

extension SourceRange {
    public static let unknown = SourceRange(file: "<unknown>", line: 0, column: 0)
}
```

Attached to IR primitives during lowering. Propagated through to
`TraceRecord.sourceRange` and written to JSONL as
`"source": {"file": …, "line": …, "col": …}`.

---

## `MeridianRuntimeError`

```swift
public enum MeridianRuntimeError: Error, Sendable {
    case toolNotFound(toolID: String)
    case instanceNotFound(name: String)
    case nestingDepthExceeded
    case cancelled
    case toolError(ToolError, sourceRange: SourceRange?)
    case assertion(message: String, sourceRange: SourceRange?)
    case assertionFailed(message: String)
    case timeout(condition: WaitCondition, sourceRange: SourceRange?)
    case approvalDenied(subject: Value, role: String, sourceRange: SourceRange?)
    case stateError(StateError, sourceRange: SourceRange?)
    case checkpointFailed(String, sourceRange: SourceRange?)
}
```

---

## Minimal harness for running generated code

```swift
import MeridianRuntime
import MeridianTools

let toolRegistry = ToolRegistry()

// Register Blueprint built-ins (http.*, file.*, json.*, regex.*, shell.run, …)
await toolRegistry.registerBuiltins()

// Register domain tools on top
await toolRegistry.register(tool: "validateOrder", .closure { args in
    return .record(["verdict": .string("valid"), "issues": .list([])])
})
await toolRegistry.register(tool: "chargePayment", .closure { args in
    return .record(["status": .string("succeeded"), "errorMessage": .string("")])
})

let instanceRegistry = InstanceRegistry.Builder()
    .register(kind: "payment_processor", name: "stripe", properties: [
        "api_key": .envVar("STRIPE_API_KEY"),
    ])
    .build()

let observer = InMemoryObserver()

let runtime = Runtime(
    toolRegistry: toolRegistry,
    instanceRegistry: instanceRegistry,
    observer: observer
)

let result = try await ProcessOrder(
    runtime: runtime,
    order: myOrder,
    customer: myCustomer
).run()

print(result)
let events = await observer.events
print(events.map(\.kind.rawValue))
```

### Resuming a run after a crash

```swift
let checkpointer = try FilesystemCheckpointer(rootURL: URL(fileURLWithPath: ".checkpoints"))
let runtime = Runtime(toolRegistry: registry, checkpointer: checkpointer, runID: "run-001")

// Restore the latest checkpoint and set the resume context.
try await runtime.prepareResume(runID: "run-001")

// Generated run() consumes the context, restores state, and skips past-checkpoint steps.
let result = try await ProcessOrder(runtime: runtime, order: order, customer: customer).run()
```

---

## Permissions and Policy

Meridian's rule engine (Phase C) generates permission gates from `may` rules in
`.meridian` source. These gates rely on two runtime types in `MeridianRuntime`:

### `Permission` and `PermissionScope`

```swift
public struct PermissionScope: Sendable {
    public let parameters: [String: Value]   // workflow params + bindings at gate time
    public let actor: Value?                 // optional actor identity (set by host)
}

public struct Permission: Sendable {
    public let subjectKind: String
    public let actionDisplayName: String
    public let description: String        // original rule text
    public let isBounded: Bool            // true iff the rule has a cap clause
    public let predicate: @Sendable (PermissionScope) -> Bool
    
    public func evaluate(_ scope: PermissionScope) -> Bool { predicate(scope) }
}
```

### `PermissionRegistry` actor

```swift
public actor PermissionRegistry {
    public static let empty: PermissionRegistry  // allows all by default
    
    public func register(_ permission: Permission)
    public func evaluate(action: String, scope: PermissionScope) -> Bool
}
```

The default `PermissionRegistry.empty` allows all actions (returns `true` for
any call where no permissions are registered for that action key).

`Runtime` exposes the registry as a `public nonisolated let permissionRegistry`:

```swift
Runtime(
    toolRegistry: …,
    permissionRegistry: myRegistry  // inject an actor-aware resolver here
)
```

---

### ⚠️  Actor-aware permission resolution: host responsibility

**By default, the `permissionRegistry` is actor-blind.** The compiled
`PermissionScope` contains workflow parameters and bindings, but
`scope.actor` is always `nil` unless the host wires it in.

**What this means in practice:**
- `must not` / `may` rules are enforced as *data predicates* (checking values
  of workflow parameters like `customer.status` or `order.totalAmount`).
- They do **not** check who the caller is (operator identity, user role, etc.)
  without host wiring.
- Bounded permissions (`up to $10000`) enforce the numeric cap against
  workflow parameters but cannot know the identity of the approver.

**To add actor-aware enforcement:**
1. Create a custom `PermissionRegistry` subclass or wrapper.
2. In each permission's `predicate`, read `scope.actor` to determine the
   acting user's identity and role.
3. Pass your custom registry to `Runtime(permissionRegistry: myRegistry)`.
4. Populate `scope.actor` by creating a custom `Runtime` subclass or by
   injecting actor context into workflow parameters before calling `run()`.

This design is intentional: Meridian's runtime has no built-in user identity
model. Permission logic that requires identity is a host concern.

---

## Choice-gate (`WaitConditionIR.choice`)

The gbrain SKILL surface uses the fifth `WaitCondition` case for the ask-user
pattern (`ask the user to choose between "A", "B".`):

```swift
case choice(prompt: String, options: [String])
```

It reuses the same continuation plumbing as `.signal`:

- `wait(.choice(prompt:options:))` registers a continuation in
  `_choiceWaiters` and suspends. The `wait.start` payload carries
  `kind = "choice"`, the prompt, and the options list, so a host UI can render
  the gate.
- `deliverChoice(_ selection: String)` stores the selection in
  `_lastChoiceSelection` and resumes the waiter.
- `consumeChoiceSelection()` returns (and clears) the last delivered selection.
  Generated `if the choice is "A",` branches call it to read the user's pick.

Timeout is not honoured for `.choice` (same as `.signal`/`.approval`/`.event`);
only `.duration` honours the clock.

---

## `shell.run` for the command surface

Fenced ` ```bash ` blocks and inline backticked `gbrain …` commands lower to
`invoke shell.run with command = "…"`. `shell.run` is the existing
`.subprocess` built-in (`/bin/sh -c {command}`), returning
`{ stdout, stderr, exitCode }`. No new tool or merconfig declaration is needed.
See [10_BUILTIN_TOOLS.md](10_BUILTIN_TOOLS.md) for its argument/return shape.

---

## Semantic traces (Wave 8)

Wave 8's semantic trace layer lives on the same record that observers receive;
there is no separate event stream:

| Type | Role |
|---|---|
| `TraceRecord` | The single runtime record: `EventKind` + projected `TraceTag`, subject, payload hash, outcome, … |
| `TraceStore` | `append`, scoped `query`, `compact`, `verifyChain` |
| `InMemoryTraceStore` | Tests and in-process replay |
| `JSONLTraceStore` | Append-only local audit trail (checksum envelope per line) |
| `TraceEvaluator` | Evaluates `traceTemporal` / `traceStatistical` / `eventPattern` queries |

Pass a store into `Runtime(traceStore:)` (or rely on generated wiring when
`=== trace ===` configures one). `Runtime.evaluateTemporal` /
`evaluateStatistical` delegate to `TraceEvaluator`. Store failures follow the
configured `storeFailurePolicy` (`fail-open` / `fail-closed` / `auto` resolved
at compile time).

Monitored assertions call `registerMonitor` to re-check a statistical query on a
cadence. Every emission carries its `EventKind`; the kind table maps it to a
`TraceTag` on the same record for temporal/statistical operators.

Full schema, ordering, capture policy, and CLI replay commands:
[19_TRACES_AND_TIME.md](19_TRACES_AND_TIME.md).

---

## Wave 4 Runtime Surface

Wave 4 did not add a runtime actor API. Generated table lookups reuse
`ToolError.implementation(code: "table.lookup_miss", ...)` so the existing
`meridianMatches(_:named:)` code-based recover matching handles
`recover from "table.lookup_miss":`.

Template formatting is emitted as a private generated Swift helper
(`meridianFormat(_:as:)`) rather than a shared runtime service. It formats
`Value` payloads for the closed formatter set used by the compiler.
