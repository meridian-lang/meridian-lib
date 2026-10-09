# Meridian — Runtime

The `MeridianRuntime` API that generated Swift imports, the built-in tool
catalog, and the semantic trace/time layer. The compiler that emits code
against this surface is documented in [02_ARCHITECTURE.md](02_ARCHITECTURE.md).

---

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

See [`02_ARCHITECTURE.md`](02_ARCHITECTURE.md) §"Domain types (`DomainEmitter`)" for
the per-path output, and [`03_LANGUAGE.md`](03_LANGUAGE.md)
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

See [04_RUNTIME.md](04_RUNTIME.md) for the full built-in catalog.

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
See [04_RUNTIME.md](04_RUNTIME.md) for its argument/return shape.

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
[04_RUNTIME.md](04_RUNTIME.md).

---

## Wave 4 Runtime Surface

Wave 4 did not add a runtime actor API. Generated table lookups reuse
`ToolError.implementation(code: "table.lookup_miss", ...)` so the existing
`meridianMatches(_:named:)` code-based recover matching handles
`recover from "table.lookup_miss":`.

Template formatting is emitted as a private generated Swift helper
(`meridianFormat(_:as:)`) rather than a shared runtime service. It formats
`Value` payloads for the closed formatter set used by the compiler.

---

## Built-in tools

*Was `docs/10_BUILTIN_TOOLS.md`.*

Meridian ships a set of **Blueprint built-in tools** in the `MeridianTools` module.
They cover the most common workflow needs — HTTP, filesystem, JSON, regex, shell
execution, deterministic LLM decision stubs, schema validation, time, UUID generation, and integration with MCP
(Message Control Plane) services.

Built-ins are **opt-in**. `ToolRegistry` starts empty. To register them, call:

```swift
import MeridianTools
let registry = ToolRegistry()
await registry.registerBuiltins()
```

Domain-specific tools (e.g. `validateOrder`, `chargePayment`) are registered
on top of built-ins:

```swift
await registry.register(tool: "validateOrder", .closure { args in
    return .record(["verdict": .string("valid"), "issues": .list([])])
})
```

Tool stubs passed via `--tool-stub` in the CLI override built-ins for that run.

---

### Tool ID catalog

| Tool ID | Family | Dispatch | Description |
|---|---|---|---|
| `http.get` | HTTP | `.http` | HTTP GET request |
| `http.post` | HTTP | `.http` | HTTP POST request |
| `http.put` | HTTP | `.http` | HTTP PUT request |
| `http.delete` | HTTP | `.http` | HTTP DELETE request |
| `file.read` | File | `.closure` | Read a UTF-8 file |
| `file.write` | File | `.closure` | Write (overwrite) a UTF-8 file |
| `file.append` | File | `.closure` | Append to a UTF-8 file |
| `json.parse` | JSON | `.closure` | Parse a JSON string into a `Value` |
| `json.stringify` | JSON | `.closure` | Serialise a `Value` to a JSON string |
| `json.transform` | JSON | `.closure` | Extract a sub-value by dot/bracket path |
| `regex.match` | Regex | `.closure` | Find all matches in text |
| `regex.replace` | Regex | `.closure` | Replace matches in text |
| `shell.run` | Shell | `.subprocess` | Run a shell command via `/bin/sh -c` |
| `mcp.call` | MCP | `.mcp` | Call an MCP method (replaceable transport) |
| `llm.chat` | LLM | `.closure` | OpenAI-compatible chat; requires `LLMProviderRegistry` configuration (fail-closed without provider) |
| `llm.decide` | LLM | `.closure` | Deterministic decision stub; hosts override |
| `llm.judge` | LLM | `.closure` | Deterministic judge stub; hosts override |
| `validate.json_schema` | Validation | `.closure` | Validate a record against a simple JSON Schema |
| `time.now` | Time | `.closure` | Return current UTC timestamp as `.dateTime` |
| `time.format` | Time | `.closure` | Format a date/dateTime as a string |
| `uuid.generate` | UUID | `.closure` | Generate a random UUID v4 string |

---

### HTTP tools

The `http.*` tools dispatch via `ToolKind.http(HTTPSpec)`. The URL template
in `HTTPSpec` has `{url}` replaced from `args["url"]`.

#### `http.get`

```
args:
  url     (String, required)   — full URL
  headers (record, optional)   — additional request headers

returns:
  status  (number)  — HTTP status code
  body    (string)  — response body text
  headers (record)  — response headers (string → string)
```

#### `http.post`, `http.put`

Same as `http.get` plus:

```
args:
  body         (string, optional) — request body text
  content_type (string, optional) — Content-Type header (default: application/json)
```

#### `http.delete`

Same as `http.get`. No request body.

#### Error behaviour

A network error (DNS failure, TLS error, etc.) throws a
`MeridianRuntimeError.toolError`. HTTP 4xx/5xx responses are returned
as normal results — check `status` if you need to distinguish them.

---

### File tools

File tools dispatch via `ToolKind.closure` backed by `MeridianTools.invoke`.
All paths are relative to the process working directory.

#### `file.read`

```
args:
  path (String, required) — file path

returns:
  (string) — UTF-8 file contents

throws:
  toolError if file cannot be read
```

#### `file.write`

```
args:
  path    (String, required) — file path
  content (String, required) — UTF-8 text to write (overwrites existing file)

returns:
  (null)
```

#### `file.append`

```
args:
  path    (String, required) — file path
  content (String, required) — UTF-8 text to append

returns:
  (null)
```

If the file does not exist, `file.append` creates it (equivalent to `file.write`).

---

### JSON tools

#### `json.parse`

```
args:
  text (String, required) — JSON string to parse

returns:
  parsed Value tree (record / list / string / number / boolean / null)

throws:
  toolError on invalid JSON
```

#### `json.stringify`

```
args:
  value (Value, optional) — value to serialise (default: .null)

returns:
  (string) — compact JSON string (keys sorted for determinism)
```

#### `json.transform`

Extract a sub-value by a dot/bracket-notation path. Returns `.null` when the
path is absent or type-mismatches occur.

```
args:
  value (Value, required) — record or list to traverse
  path  (String, optional) — e.g. "order.items[0].id"

returns:
  sub-value at path, or .null
```

Path examples:

| Path | Input | Result |
|---|---|---|
| `"order.id"` | `{"order":{"id":"x"}}` | `"x"` |
| `"items[1]"` | `{"items":["a","b","c"]}` | `"b"` |
| `"user.tags[0]"` | `{"user":{"tags":["admin"]}}` | `"admin"` |

---

### Regex tools

Both regex tools use `NSRegularExpression` (ICU regex engine) for pattern matching.

#### `regex.match`

```
args:
  pattern (String, required) — ICU regex pattern
  text    (String, required) — input text

returns:
  record:
    matched (boolean) — true if at least one match found
    matches (list)    — one record per match:
      text    (string) — matched text
      range   (record) — { location, length }
      groups  (list)   — captured groups (index 0 = full match)

throws:
  toolError on invalid regex pattern
```

#### `regex.replace`

```
args:
  pattern     (String, required) — ICU regex pattern
  text        (String, required) — input text
  replacement (String, required) — replacement template (ICU back-references: $0, $1, …)

returns:
  (string) — text with all matches replaced

throws:
  toolError on invalid regex pattern
```

---

### Shell tool

#### `shell.run`

Dispatches via `ToolKind.subprocess` with `/bin/sh -c {command}`.

```
args:
  command (String, required) — shell command to execute

returns:
  record:
    stdout    (string)  — captured stdout
    stderr    (string)  — captured stderr
    exit_code (number)  — exit code (0 = success)

throws:
  toolError on process launch failure or timeout
```

**Security note:** `shell.run` executes arbitrary shell commands. Only use
with trusted inputs in production workflows.

**Command surface mapping:** the gbrain SKILL surface lowers fenced
` ```bash `/` ```sh `/` ```shell ` blocks and inline backticked `gbrain …`
commands (inside a `procedure`-role section) to `invoke shell.run with command =
"<verbatim>"`. A multi-line block lowers to one invoke per command line. This
reuses the existing `.subprocess` dispatcher — no new tool, no merconfig
declaration — and is a fully deterministic `invoke` (never an LLM). See
[09_SKILL_PORTING.md](09_SKILL_PORTING.md) §"Command surface".

---

### MCP tool

#### `mcp.call`

`mcp.call` dispatches through a replaceable `MCPClient` protocol adapter.
This keeps the built-in orchestration logic decoupled from any specific MCP
service or transport.

```
args:
  method (String, required) — MCP method name (e.g. "resources/read")
  params (record, optional) — method parameters

returns:
  Value — the MCP result (tool-defined shape)

throws:
  toolError on network/transport error or MCP error response
```

#### Transport configuration

Two built-in transports are provided:

**HTTP JSON-RPC** — sends `POST {"jsonrpc":"2.0","method":…,"params":…}` to an endpoint:

```swift
registry.mcpClient = HTTPJSONRPCMCPClient(endpoint: URL(string: "https://my-mcp.example.com/rpc")!)
```

**Subprocess stdio** — launches a process and communicates over stdin/stdout:

```swift
registry.mcpClient = StdioMCPClient(binary: "/usr/local/bin/my-mcp-server", args: [])
```

**Custom transport** — implement `MCPClient` and assign:

```swift
public protocol MCPClient: Sendable {
    func call(method: String, params: [String: Value]) async throws -> Value
}
registry.mcpClient = MyCustomMCPClient()
```

The default `MCPSpec()` with no transport configured throws
`ToolError.implementation(code: "mcp.requires_registry", …)`.

---

### LLM tools

Meridian ships a pluggable `LLMProvider` protocol in `MeridianRuntime` and
default adapters in `MeridianTools`:

| Component | Role |
|---|---|
| `DeterministicLLMProvider` | Test-safe stand-in; no network I/O |
| `HTTPLLMProvider` | OpenAI-compatible chat-completions HTTP client |
| `LLMProviderRegistry` | Resolves override → env → deterministic/fail-closed |

#### Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `MERIDIAN_LLM_API_URL` | For live LLM use | Chat-completions endpoint (must be `http`/`https`) |
| `MERIDIAN_LLM_API_KEY` | Optional | Bearer token sent as `Authorization: Bearer …` |
| `MERIDIAN_LLM_MODEL` | Optional | Model name (default: `gpt-4o-mini`) |

When `MERIDIAN_LLM_API_URL` is unset:

- `llm.chat` throws `llm.not_configured` (fail-closed).
- `llm.decide` / `llm.judge` use `DeterministicLLMProvider` (test-safe).
- `migrate-skill --repair` and `canonicalize --propose` exit with a CLI error.

Hosts can inject a provider without env vars via `LLMProviderRegistry.setOverride(_:)`
(tests) or `Runtime.Builder.wireLLMJudgmentTools(from:)` / `ToolRegistry.registerLLMJudgmentTools(provider:)`.

#### `llm.chat`

Requires a configured provider (`MERIDIAN_LLM_API_URL` or an override). Calling
it without configuration throws:

```
ToolError.implementation(
    code: "llm.not_configured",
    message: "LLM provider is not configured — set MERIDIAN_LLM_API_URL …"
)
```

Args: `prompt` (string) or `messages` (list of `{role, content}` records).
Returns a record `{ content, role, model, input_tokens, output_tokens }`.

#### `llm.decide` / `llm.judge`

When no HTTP provider is configured, these use `DeterministicLLMProvider`:
affirmative questions containing `yes`/`true` return `.boolean(true)`, others
return `.boolean(false)`. With `MERIDIAN_LLM_API_URL` set, they delegate to the
HTTP provider with a true/false system prompt.

Override example:

```swift
await registry.register(tool: "llm.decide", .closure { args in
    try await MeridianTools.invoke("llm.decide", args: args)
})
```

---

### Schema validation tool

#### `validate.json_schema`

Performs a lightweight required-fields check (not a full JSON Schema validator).

```
args:
  schema (record, required) — schema object with optional "required" list
  value  (record, required) — value to validate

returns:
  record:
    valid  (boolean) — true if all required fields are present
    errors (list)    — list of "missing:<fieldName>" strings
```

For full JSON Schema validation (draft-07 or later), wire up a library-backed
closure in place of the built-in.

---

### Time tools

#### `time.now`

```
args:
  (none)

returns:
  (dateTime) — current UTC timestamp as a Value.dateTime(Date())
```

#### `time.format`

```
args:
  value    (date | dateTime, optional) — date to format; defaults to now
  format   (String, optional)          — strftime-style format string;
                                         if omitted, ISO 8601 is used
  locale   (String, optional)          — locale identifier (default: en_US_POSIX)
  timezone (String, optional)          — IANA timezone ID (default: UTC)

returns:
  (string) — formatted date string
```

Examples:

| `format` | Output |
|---|---|
| `"yyyy-MM-dd"` | `"2026-04-29"` |
| `"HH:mm:ss"` | `"07:45:00"` |
| (omitted) | `"2026-04-29T07:45:00Z"` |

---

### UUID tool

#### `uuid.generate`

```
args:
  (none)

returns:
  (string) — uppercase UUID v4 string, e.g. "550E8400-E29B-41D4-A716-446655440000"
```

---

### Error shapes

Built-in tools that fail throw one of the standard `ToolError` cases:

```swift
public enum ToolError: Error, Sendable {
    case argumentCoercion(field: String, expected: String, actual: String)
    case implementation(code: String, message: String, cause: Error?)
    case network(code: String, message: String, underlying: Error?)
    case subprocess(exitCode: Int, stderr: String)
    case timeout(toolID: String, after: Duration)
}
```

These are wrapped by the runtime into `MeridianRuntimeError.toolError(ToolError, …)`
which is what a `recover` clause or test sees.

---

### Registration summary

```swift
import MeridianTools
import MeridianRuntime

// Start with built-ins
let registry = ToolRegistry()
await registry.registerBuiltins()

// Optionally configure MCP transport
registry.mcpClient = HTTPJSONRPCMCPClient(endpoint: URL(string: "https://mcp.example.com")!)

// Register domain tools alongside built-ins
await registry.register(tool: "validateOrder", .closure { args in … })
await registry.register(tool: "chargePayment", .closure { args in … })

let runtime = Runtime(toolRegistry: registry)
```

---

## Traces and time

*Was `docs/19_TRACES_AND_TIME.md` (Wave 8).*

Status: Wave 8 landed and the documentation now reflects **implemented,
named-test-backed behavior**. Cross-reference
`docs/cookbook/MERIDIAN_SEMANTICS.md`.

---

### 1. Purpose

Wave 8 makes traces part of Meridian's semantics, not just its debugging story.
This document is the operational companion to semantics clauses 4 through 6:

- the persisted trace schema
- the store behaviors that temporal/statistical meaning depends on
- ordering, scope, keying, and retention
- temporal/statistical lowering and replay
- monitors, capture policy, privacy, and performance limits

The semantics document is normative. This document describes how the repository
currently realizes that meaning.

---

### 2. Semantic Trace Record

The persisted record is `TraceRecord`
(`Sources/MeridianRuntime/Trace/TraceRecord.swift`). Its JSON keys are:

| Key | Type | Meaning |
| --- | --- | --- |
| `schemaVersion` | Int | Current value is `1`. |
| `id` | String | Monotonic ULID-style identifier; lexicographic order is meaningful. |
| `at` | Date | Runtime timestamp. |
| `ingestOrder` | Int | Monotone fallback order witness. |
| `run` | String | Run identifier. |
| `step` | String | Stable step path for history continuity. |
| `skillName` | String | History identity root. |
| `skillVersionHash` | String | Audit metadata only, not a history partition key. |
| `tag` | `TraceTag` | Closed semantic tag set. |
| `subject` | String? | Named thing/step/event the record is about. |
| `subjectKey` | String? | Per-instance key for keyed temporal/statistical definitions. |
| `payload` | `[String: Value]`? | Structured payload when capture policy keeps it. |
| `payloadHash` | String | Always present; canonical-JSON SHA-256. |
| `outcome` | `TraceOutcome`? | `success`, `failure`, or `indeterminate`. |
| `operationalDetail` | String? | Non-semantic runtime detail retained for audit. |
| `kind` | `EventKind` | Emission discriminator (`EventKind.rawValue`); decodes `.emit` when absent and still reads the pre-Phase-4 `legacyKind` key. |
| `sourceRange` | `SourceRange`? | Source span when the emission carries one. |
| `parentRunID` | String? | Parent run for nested workflows. |
| `parentSequence` | Int? | Parent emission sequence for nested workflows. |

Tested invariants:

- `schemaVersion` starts at `1`; both stores accept current and N-1 schema
  versions.
- `payloadHash` is stable across JSON key order (`canonical JSON hash is stable
  across key order`).
- every `EventKind` projects to its `TraceTag`/outcome/subject through the kind
  table (`the kind table maps every EventKind with subject priority`).
- `skillVersionHash` does not partition `across all runs` history
  (`SEM_4_09 across-all-runs ignores version hash when skill identity is stable`).

The closed `TraceTag` set is:

`invoked`, `completed`, `failed`, `emitted`, `asserted`, `assert-failed`,
`branched`, `iterated`, `judged`, `committed`, `recovered`, `violated`.

Temporal/statistical operators query this semantic tag layer, not raw
`EventKind`.

---

### 3. Legacy Event Migration

`MeridianRuntime` still emits legacy `EventKind` values internally, but Wave 8
defines a stable semantic projection. The important mappings are:

- invoke start/end/error -> `invoked` / `completed` / `failed`
- plan/autonomy start/step/end/error/rejected -> `judged`
- branch/iterate/assert/emit/commit/recover -> `branched` / `iterated` /
  `asserted` or `assert-failed` / `emitted` / `committed` / `recovered`
- workflow lifecycle, bind, and wait lifecycle remain `operationalDetail`
  material unless adapted into a higher-level semantic record

This is pinned by:

- `the kind table maps every EventKind with subject priority`
- `SEM_4_04 judgment boundary maps to a judged record carrying a payload hash, kind, and tool scope`

Judgment boundaries retain a content hash, the runtime `kind`, a tool-scope
summary (`tool_count`), and the explicit scoped-tool-id list (`scoped_tools`)
in the payload.

---

### 4. Stores, Persistence, And Integrity

Wave 8 ships two store implementations:

- `InMemoryTraceStore` for tests, replay fixtures, and direct runtime use
- `JSONLTraceStore` for append-only local persistence and audit trails

See `docs/04_RUNTIME.md` for the JSONL envelope, capture policies, and shell-hole redaction.

The shared `TraceStore` protocol is:

- `append(_:)`
- `query(scope:runID:skillName:window:pattern:)`
- `compact(retention:now:)`
- `capabilities`
- `verifyChain(runID:)`

#### 4.1 JSONL format

`JSONLTraceStore` persists one envelope per line:

```json
{ "record": <TraceRecord>, "checksum": "<canonical sha256>" }
```

The checksum covers the decoded `TraceRecord`, not the raw line bytes. On load:

- a bad checksum on a non-final line is a corruption error
- a torn final line is quarantined to a sibling
  `*.quarantine-<timestamp>` file and ignored on reopen
- the file is rewritten without the torn line after successful recovery

This behavior is pinned by `torn final JSONL line is quarantined and ignored on reopen`.

#### 4.2 Durability and locking

`JSONLTraceStore` uses:

- a sidecar advisory lock file (`.lock`) via `lockf`
- durable append + `fsync` on the file and parent directory
- durable rewrite via temp file + replace + `fsync`

Within the retained window, records are append-only. Compaction removes expired
records only (`SEM-4-01 append-only within retention and retention compaction drops expired only`).

#### 4.3 Query behavior

Both stores support the same observable query behavior:

- current-run queries sort by `ingestOrder`, then `at`, then `id`
- across-run queries sort by `at`, then `ingestOrder`, then `id`
- filters combine scope, skill, time window, tags, subject, subject key,
  outcome, and exact payload field matches

`JSONLTraceStore` maintains simple in-memory indexes for `run`, `tag`,
`subject`, and cross-run time order. Behavioral parity with the in-memory store
is pinned by `RISK-W8-05 in-memory and JSONL stores stay behaviorally aligned`.

---

### 5. Retention, Closed World, And Time

`TraceConfiguration.retention` is semantic, not housekeeping. Wave 8 behavior:

- temporal/statistical operators are closed-world over retained history
- a query window larger than configured retention is a compile-time
  `MER-TMP-011` (`traceWindowExceedsRetention`)
- the diagnostic names both the requested window and configured retention

Pinned by:

- `trace section and tool capture policies parse`
- `SEM_2_12 trace durations stay physical and deployment zones stay explicit`
- `NS-C-02 / SEM-4-06 window greater than retention reports MER-TMP-011 naming both durations`

Durations are physical time only: `7 days` means exactly `604_800` seconds.
`deployment zone` is explicit trace configuration metadata and is not inferred
from the host.

---

### 6. Ordering, Scope, Keying, And History Identity

Temporal/statistical meaning depends on four separate axes.

#### 6.1 Ordering

- current-run queries use run-local emission order
- across-run queries use `at`, then `ingestOrder`, then `id`

Pinned by `SEM-4-02 ordering uses run order locally and at-ingest-id globally`.

#### 6.2 Scope

- default scope is the current run
- `across all runs` widens only to runs with the same `skillName`

Cross-skill history is not expressible in v1.

Pinned by `SEM_4_03 across-all-runs uses skill scope and global ordering`.

#### 6.3 Keying

Definitions on keyed kinds implicitly restrict matching by `subjectKey`.

- keyed temporal definitions thread a `subjectKeyExpr`
- keyed statistical definitions do the same
- unkeyed definitions are rejected with `MER-TMP-016`

Pinned by:

- `SEM_5_09 keyed temporal definition threads subject key into lowered IR`
- `SEM_5_09 keyed statistical definition threads subject key into lowered IR`
- `SEM_5_10 temporal definition on unkeyed kind reports MER-TMP-016`
- `SEM_5_09 subject key restricts temporal matching`

#### 6.4 Stable step paths and skill version hashes

History continuity is keyed by `skillName + stable step path`, not by
`skillVersionHash`.

- unrelated edits must not perturb unaffected step paths
- whitespace-only edits may leave `skillVersionHash` stable
- meaning edits may change `skillVersionHash`
- `skillVersionHash` remains audit metadata even when it changes

Pinned by:

- `stable step paths survive unrelated edits`
- `SEM_4_09 across-all-runs ignores version hash when skill identity is stable`

---

### 7. Temporal Operators

`TraceEvaluator` implements a pure-past fragment over retained history.

| Surface | Runtime query | Pinned behavior |
| --- | --- | --- |
| `E has ever occurred` | `.ever` | `SEM_5_02 ever matches retained scoped history` |
| `E has occurred within the last D` | `.withinWindow` | `SEM_5_03 withinWindow uses inclusive old end` |
| `E has occurred N times within the last D` | `.countInWindow` | `SEM_5_04 countInWindow compares at least at most exactly` |
| `E has occurred N times in a row` | `.inARow` | `SEM_5_05 inARow uses qualifying subsequence and prevented invoke does not qualify` |
| `since the last E, C` | `.sinceLast` | `SEM_5_06 sinceLast is strict after anchor and indeterminate without anchor` |

Other pinned temporal semantics:

- pure-past only: future-looking forms are rejected (`MER-TMP-013`)
- vague `recently` is rejected (`MER-TMP-017`)
- bare perfect without `ever`/window/count is rejected (`MER-TMP-010`)
- causal `since` is rejected (`MER-TMP-012`)
- progressive aspect is rejected (`MER-TMP-018`)

#### 7.1 `since the last` holds resolution

`since the last <anchor>` keeps authored wording in IR but lowers the runtime
query from a resolved event pattern:

1. direct event-pattern holds: supported
2. event-backed adjective holds: supported and expanded to an event pattern
3. pure state-predicate holds: rejected with `MER-TMP-019`

Pinned by:

- `since-the-last with an event-backed adjective holds lowers to a runtime-evaluable pattern`
- `MER-TMP-019 a pure state-predicate 'since the last' holds is rejected`

Residual limitation: Meridian v1 does **not** retain state history, so a pure
state predicate such as `the service is healthy since the last ...` is still
unsupported.

#### 7.2 In-a-row caveat

Semantic ordering is implemented and tested, including prevented invokes and
cross-run/current-run contrast. The advisory lint for author-surprising
simultaneous interleavings is also implemented: `across all runs` scoped
`in a row` queries warn about interleaved ordering, while `current run` `in a
row` and `count in window` queries do not (they have no cross-run interleaving
to warn about). Pinned by `SEM_5_11 across-all-runs in-a-row warns about
interleaved ordering`, `SEM_5_11 current-run in-a-row does not warn`, and
`SEM_5_11 count-in-window does not warn`.

---

### 8. Statistical Operators And Monitors

Wave 8 supports:

- explicit percentage bounds: `at least N%`, `at most N%`
- denominator choice: `of runs` vs `of occurrences`
- lexical sugar: `usually` / `rarely`
- optional windows
- sample-floor indeterminacy
- monitored statistical assertions

Pinned behavior:

- `SEM_6_01 TraceStatistical occurrences compare against explicit threshold`
- `SEM_6_02 TraceStatistical sample floor yields indeterminate`
- `SEM_6_03 TraceStatistical runs use the last qualifying event per run`
- `SEM_6_04 with 95% confidence is reserved and rejected`
- `SEM_6_05 syntactic analysis is conservative and transitive only`

`usually` and `rarely` verbalize numerically; they do not print as fuzzy prose
in Canonical English.

#### 8.1 Monitored assertions

A statistical `assert` lowers to a monitored, non-blocking assertion when it is
configured as a monitor:

- cadence comes from `=== trace ===` `default monitor cadence:` unless overridden
- generated Swift registers the monitor with
  `runtime.registerMonitor(query:cadence:message:blocking:step:sourceRange:)`
- monitored statistical asserts allow `indeterminate` outcomes and do not use
  branch-style totality enforcement

Pinned by:

- `SEM_2_11 decision-point totality is not enforced on monitored statistical assertions`
- `etl pipeline reliability watch compiles monitor cadence and denominator contrast`
- `erp payment failure monitor compiles default-cadence monitor and streak hook`

---

### 9. Compound Note Form

`proceed, and note "<text>" in the <binding>` is a real Wave 8 surface, not a
placeholder. It:

- requires an already-declared binding
- requires the binding to be `text`
- desugars to a text-appending `rebind`
- introduces no new IR primitive

Pinned by:

- `COOK-14 compound note desugars to a rebind that appends text (no new IR primitive)`
- `COOK-14 compound note canonical form round trips`
- `COOK-14 compound note into an undeclared binding reports MER-REF-004`
- `COOK-14 compound note into a non-text binding reports MER-TYP-001`

Generated Swift appends with ordinary `state.rebind(...)` string concatenation.

---

### 10. K3 And Decision-Point Totality

Wave 8 uses Kleene strong three-valued logic when a subexpression is
possibly-indeterminate.

Pinned truth-table examples:

- `false and unknown = false`
- `true or unknown = true`
- `true and unknown = unknown`
- `unknown or false = unknown`
- `not unknown = unknown`

These are all covered by `SEM-2-10 K3 truth table`.

Decision-point totality today:

- branch conditions are checked
- monitored statistical asserts are intentionally not branch-totality checked
- ordinary `otherwise` covers `false` plus `indeterminate` when no unknown arm exists
- when an explicit unknown arm exists, `otherwise` covers `false` only

The D7a blocking-assert/obligation-site variant is also implemented: a
blocking `assert` (no `otherwise` fallback) whose lowered condition
structurally contains `since the last` reports `MER-STA-001` at compile time,
since the anchorless case can be indeterminate and a blocking assert site has
no branch to fall through to. A branch with an explicit `otherwise` remains
accepted. Pinned by `NS-C-07 Broken Twin line 7 reports MER-STA-001 for a
blocking assert with no default policy` and `NS-C-07 near miss branch with
otherwise remains accepted`.

---

### 11. Capture Policy, Privacy, And Store Failures

#### 11.1 Capture policy

Per-tool capture policy supports:

- `full`
- `hash-only`
- `redacted(fields)`

The content hash is mandatory under all three. This is pinned by:

- `trace section and tool capture policies parse`
- `governance access review freshness compiles production trace capture policy`
- `clinical handoff reliability monitor compiles privacy-safe tool scope`

Practical privacy guidance from the current implementation:

- treat the trace store as a shadow data system
- use `hash-only` when historical existence/comparison is enough
- use `redacted(fields)` when the payload shape is needed but particular fields
  must not be stored in clear
- remember that judgment/tool boundaries can carry sensitive inputs or outputs;
  capture policy applies there too

Related compile-time trace logging (`ParserTrace`) redacts obvious secret-bearing
fields before emission, but that is separate from semantic trace-store capture.

Residual: D9's production-profile guard is still missing. A production profile
without explicit per-tool capture policies still compiles today.

#### 11.2 Store failure policy

Wave 8 supports:

- **fail-closed** — append/observer failures propagate on strict emits
- **fail-open** — after recovery, a degraded-witnessing marker is appended

**`.auto` always resolves to `.failClosed` at compile time.** `TraceIdentityPlanner`
replaces unresolved `.auto` (including when the `=== trace ===` section omits an
explicit policy) with `.failClosed` before codegen, so `Runtime` never sees `.auto`
(which would otherwise behave as fail-open). Explicit `.failOpen` / `.failClosed`
declarations are preserved. `TraceConfiguration.default.storeFailurePolicy` is
`.failClosed` for hosts that construct a runtime without the planner.

Pinned by `TraceIdentityPlannerD8Tests` and:

- `SEM-4-07 fail-closed rethrows append failures on strict emits`
- `SEM-4-07 fail-open emits a degraded-witnessing marker after recovery`

The fail-open marker uses semantic tag `failed`, subject `trace-store`, and
`operationalDetail == "degraded-witnessing-marker"`.

#### 11.3 Terminal failures and monitor violations

- **`workflow.failed`** — generated `run()` wraps failures in `do/catch` and
  calls `Runtime.workflowFailed(…)` before rethrowing, emitting a terminal
  `EventKind.workflowFailed` (`"workflow.failed"`) with workflow name, error,
  optional `step`, and `source` range. Cancellation is not recorded.
- **`violated`** — blocking monitor assertions append a `TraceRecord` with
  tag `.violated`, `outcome: .failure`, and payload fields `message`, `step`,
  `subject_key` (from the monitor's keyed definition). This is semantic trace
  material, distinct from legacy `assert.failed` events.

#### 11.4 Driver `TraceStore` wiring

When a workflow carries `runtimeTraceConfiguration` (from `=== trace ===`),
generated drivers and `DriverSourceBuilder` wire a store before `Runtime` init:

```
runtimeTraceConfiguration (compiled from merconfig + TraceIdentityPlanner)
  → switch store { .memory → InMemoryTraceStore, .file → JSONLTraceStore }
  → Runtime(traceStore:, traceConfiguration:, traceSkillIdentity:)
```

`meridian run` / `RuntimeExecutor` use this bootstrap when trace configuration
is present; in-memory stores are used for tests and ephemeral runs, file-backed
`JSONLTraceStore` for persisted audit trails (temp path keyed by `runID` in the
generated driver). Semantic records are appended from `Runtime.emit` alongside
legacy `Observer` events — the two sinks are independent but share `runID`,
step paths, and source ranges from the manifest map.

---

### 12. Replay, Verification, And Benchmarks

#### 12.1 Replay semantics

Replay is pure over `(store, TraceEvaluationContext)`:

- `evaluationInstant` is explicit input
- the evaluator does not read wall clock during replay
- fixed context yields deterministic truth values and witness ids

Pinned by:

- `SEM_5_07 fixed context yields deterministic result`
- `SEM_5_08 replay semantics depend only on explicit evaluation instant`
- `SEM_5_08 in-memory and JSONL replay results agree across operator families`
- `SEM_5_08 replay result encoding is byte-identical`

#### 12.2 CLI surfaces

Wave 8 adds these audit/replay commands:

- `meridian trace eval <trace.jsonl> "<expression>" --at <iso8601>`
- `meridian trace-eval ...` as a top-level alias
- `meridian trace verify <trace.jsonl> --run <id> [--json]`
- `meridian bench-trace [--format json|text]`

Pinned CLI behavior:

- `trace eval JSON schema is stable`
- `trace-eval alias is byte-identical across repeated replays`
- `trace eval rejects ambiguous current-run replay`
- `bench-trace JSON schema covers all measurement combinations`

Current `trace eval` limitations:

- it only replays expressions that lower to temporal/statistical queries
- it supports simple `whose <field> is <value>` equality payload predicates
  (event and statistical patterns); a predicate that doesn't reduce to that
  shape is a `ValidationError`, not a silent drop
- current-run replay requires exactly one run in the store
- replay currently infers exactly one `skillName` from the store contents

Pinned by `trace eval replays a whose-qualified event payload predicate`
(matching vs. non-matching payload values through the CLI end-to-end) and
`8D trace eval replays a statistical expression across all runs` in
`Tests/MeridianCLITests/TraceReplayCommandTests.swift`.

#### 12.3 Bench artifact and interpretation

The runner measures:

- dataset sizes `10_000` and `100_000`
- both store kinds (`in_memory`, `jsonl`)
- both `cold` and `warm` labels
- operator families `ever`, `window`, `count`, `streak`, `since`,
  `statistical_frequency`

Interpret the numbers carefully:

- the benchmark uses one store instance per dataset
- `warm` means "after an extra warm-up evaluation for that family"
- `cold` does **not** recreate the store from scratch for every family
- on JSONL, the very first evaluation on a fresh store also pays lazy file-load cost

The artifact is therefore best treated as comparative implementation evidence,
not a portable SLA.

---

### 13. Performance And Limits

What Wave 8 proves today:

- the semantic evaluator is deterministic
- the in-memory and JSONL stores are behaviorally aligned
- benchmark output is committed and reproducible through `meridian bench-trace`

What it does **not** promise:

- distributed trace backends
- OpenTelemetry export
- remote trust anchors or signatures
- a universally applicable latency target across machines
- state-history-backed `since the last` for pure state predicates

If a stronger backend is ever needed, the justification point is measured
benchmark pain, not speculation.

---

### 14. Diagnostics And Reservations

#### 14.1 Diagnostic families

| Code | Meaning | Coverage |
| --- | --- | --- |
| `MER-TMP-010` | bare perfect trace predicate | `NS-C-01` |
| `MER-TMP-011` | window exceeds retention | `NS-C-02 / SEM-4-06` |
| `MER-TMP-012` | causal `since` form | `NS-C-03` |
| `MER-TMP-013` | future trace predicate | `NS-C-05` |
| `MER-TMP-014` | unknown trace step | near-miss check against the subject's declared tool-name vocabulary — `GAP-TMP-14-15` |
| `MER-TMP-015` | unknown trace payload field | near-miss check against the subject's declared tool parameter names — `GAP-TMP-14-15` |
| `MER-TMP-016` | unkeyed temporal/statistical definition | `SEM_5_10` |
| `MER-TMP-017` | vague `recently` | `NS-C-04` |
| `MER-TMP-018` | progressive trace predicate | `COOK-20` |
| `MER-TMP-019` | pure state-predicate `since the last` holds | `MER-TMP-019 ...` |
| `MER-STA-001` | missing unknown/default handling at a decision point | `NS-C-06`, `SEM_6_02`, `NS-C-07` (D7a blocking-assert variant) |
| `MER-STA-002` | reserved confidence wording | `SEM_6_04` |
| `MER-STA-003` | vague statistical frequency wording | `mersta003VagueFrequency` ("most of the time") |
| `MER-REF-004` | compound-note binding undeclared | `COOK-14` |
| `MER-TYP-001` | compound-note binding not text | `COOK-14` |

#### 14.2 `MER-TMP-014` / `MER-TMP-015` scope note

No Wave 8 requirement remains open. `MER-TMP-014`/`MER-TMP-015` are **not**
a closed instrumentation/payload-shape registry — Meridian has no such
registry, and a step or `whose` field the compiler has never seen still
compiles (open-world instrumentation is intentional: workflows can invoke
tools and reference their outputs freely). What they *do* check is a
near-miss: a temporal adjective's event-pattern subject/payload is compared
against the subject kind's declared tool vocabulary (step names) and that
tool's declared parameter names (payload fields) inside
`lowerRegisteredDefinitions()`; a name that's *close* to — but not exactly —
a declared name (e.g. a typo like `deply` for a declared `deploy.rollback`
tool, or `targt` for a declared `target` parameter) is rejected with a
"declared step names in scope" / field-name suggestion, while a novel,
self-consistent name with no near-miss compiles cleanly. Pinned by
`GAP-TMP-14-15` and directly by
`Tests/MeridianCoreTests/Inform7/TraceTemporalInform7Tests.swift`.

---

## Trace storage and export

*Was `docs/24_TRACE_STORAGE.md`.*

Status: Final Wave Closure Phase G (2026-07-12). Companion to
`docs/04_RUNTIME.md`.

---

### 1. Store implementations

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

### 2. `=== trace ===` auto-wiring

`Runtime.Builder` auto-wires a store from the compiled
`RuntimeTraceConfiguration`:

| `store` | Required merconfig key | Auto-wired implementation |
| --- | --- | --- |
| `memory` | — | `InMemoryTraceStore` |
| `file` | optional `store path:` | `JSONLTraceStore` (temp path when omitted) |

---

### 3. Tool capture policy

`TraceCapturePolicy` modes: `full`, `hash-only`, `redacted (fields)`, and
`omitted` (merconfig: `omitted`).

#### Shell-hole redaction

For `shell.run`, `ShellHoleRedaction` redacts `command`/`script`/`stdin` in invoke-start traces and `stdout`/`stderr`/`output_summary` in invoke-end traces according to capture policy (or default sensitive-key redaction when no explicit policy is set).

---

### 4. Tests

`Tests/MeridianRuntimeTests/Trace/PhaseGTraceInfrastructureTests.swift`:

- Shell-hole redaction
- `recordViolation` emits a violated record on store
