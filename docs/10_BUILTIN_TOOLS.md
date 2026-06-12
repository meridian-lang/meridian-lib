# Meridian — Built-in Tools Reference

Meridian ships a set of **Blueprint built-in tools** in the `MeridianTools` module.
They cover the most common workflow needs — HTTP, filesystem, JSON, regex, shell
execution, schema validation, time, UUID generation, and integration with MCP
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

## Tool ID catalog

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
| `llm.chat` | LLM | `.closure` | **Intentionally not implemented** — see below |
| `validate.json_schema` | Validation | `.closure` | Validate a record against a simple JSON Schema |
| `time.now` | Time | `.closure` | Return current UTC timestamp as `.dateTime` |
| `time.format` | Time | `.closure` | Format a date/dateTime as a string |
| `uuid.generate` | UUID | `.closure` | Generate a random UUID v4 string |

---

## HTTP tools

The `http.*` tools dispatch via `ToolKind.http(HTTPSpec)`. The URL template
in `HTTPSpec` has `{url}` replaced from `args["url"]`.

### `http.get`

```
args:
  url     (String, required)   — full URL
  headers (record, optional)   — additional request headers

returns:
  status  (number)  — HTTP status code
  body    (string)  — response body text
  headers (record)  — response headers (string → string)
```

### `http.post`, `http.put`

Same as `http.get` plus:

```
args:
  body         (string, optional) — request body text
  content_type (string, optional) — Content-Type header (default: application/json)
```

### `http.delete`

Same as `http.get`. No request body.

### Error behaviour

A network error (DNS failure, TLS error, etc.) throws a
`MeridianRuntimeError.toolError`. HTTP 4xx/5xx responses are returned
as normal results — check `status` if you need to distinguish them.

---

## File tools

File tools dispatch via `ToolKind.closure` backed by `MeridianTools.invoke`.
All paths are relative to the process working directory.

### `file.read`

```
args:
  path (String, required) — file path

returns:
  (string) — UTF-8 file contents

throws:
  toolError if file cannot be read
```

### `file.write`

```
args:
  path    (String, required) — file path
  content (String, required) — UTF-8 text to write (overwrites existing file)

returns:
  (null)
```

### `file.append`

```
args:
  path    (String, required) — file path
  content (String, required) — UTF-8 text to append

returns:
  (null)
```

If the file does not exist, `file.append` creates it (equivalent to `file.write`).

---

## JSON tools

### `json.parse`

```
args:
  text (String, required) — JSON string to parse

returns:
  parsed Value tree (record / list / string / number / boolean / null)

throws:
  toolError on invalid JSON
```

### `json.stringify`

```
args:
  value (Value, optional) — value to serialise (default: .null)

returns:
  (string) — compact JSON string (keys sorted for determinism)
```

### `json.transform`

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

## Regex tools

Both regex tools use `NSRegularExpression` (ICU regex engine) for pattern matching.

### `regex.match`

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

### `regex.replace`

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

## Shell tool

### `shell.run`

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
[13_SKILL_MD_PORTING.md](13_SKILL_MD_PORTING.md) §"Command surface".

---

## MCP tool

### `mcp.call`

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

### Transport configuration

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

## LLM tool

### `llm.chat`

`llm.chat` is **intentionally not implemented** in v1. Calling it throws:

```
ToolError.implementation(
    code: "llm.not_implemented",
    message: "llm.chat is intentionally not implemented yet"
)
```

This is a deliberate user-approved design decision — the tool ID is reserved
so workflows can reference `llm.chat` today and the provider can be wired up
later without changing any source. When implementing, register a closure or
replace the built-in with your provider:

```swift
await registry.register(tool: "llm.chat", .closure { args in
    // Connect to your LLM provider here.
    let messages = args["messages"]?.asList ?? []
    let response = try await myLLMClient.chat(messages: messages)
    return .record(["content": .string(response), "role": .string("assistant")])
})
```

---

## Schema validation tool

### `validate.json_schema`

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

## Time tools

### `time.now`

```
args:
  (none)

returns:
  (dateTime) — current UTC timestamp as a Value.dateTime(Date())
```

### `time.format`

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

## UUID tool

### `uuid.generate`

```
args:
  (none)

returns:
  (string) — uppercase UUID v4 string, e.g. "550E8400-E29B-41D4-A716-446655440000"
```

---

## Error shapes

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

## Registration summary

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
