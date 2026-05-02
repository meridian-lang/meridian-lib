# ``MeridianRuntime``

The runtime library consumed by Swift code generated from `.meridian` sources.

## Overview

`MeridianRuntime` provides the building blocks every compiled workflow
depends on:

- ``Runtime`` — the central actor that drives a single workflow run,
  emits events, and owns the per-run sequence counter.
- ``State`` — per-run key-value store backing `bind` / `state.get(...)`.
- ``Value`` — the union type representing every value that crosses the
  Meridian / Swift boundary (strings, numbers, money, durations,
  records, lists, references, opaque-Codable boxes).
- ``ToolRegistry`` — lookup table from tool ID to invocation strategy
  (closure, subprocess, HTTP, MCP).
- ``InstanceRegistry`` — lookup table for vocabulary instances such as
  `primary mailer`.
- ``Observer`` — protocol for streaming ``Event`` records to disk,
  stdout, or memory.
- ``Checkpointer`` — protocol for persisting workflow state to a
  durable medium so a `resume` call can pick up where a process left
  off.

A typical compiled workflow looks roughly like:

```swift
public struct ProcessOrder {
    public let order: Order
    public func run(runtime: Runtime) async throws -> Value {
        await runtime.workflowStarted(workflowName: "ProcessOrder",
                                      parameters: ["orderId": .string(order.id)])
        var state = State()
        state.bind("order", order)
        let verdict = try await runtime.invoke(
            tool: "validateOrder",
            args: ["order": state.get("order") ?? .null]
        )
        // …
        await runtime.complete(reason: nil)
        return .null
    }
}
```

## Topics

### Driving a workflow

- ``Runtime``
- ``Runtime/invoke(tool:args:sourceRange:)``
- ``Runtime/emit(event:payload:sourceRange:)``
- ``Runtime/wait(_:timeout:sourceRange:)``
- ``Runtime/checkpoint(label:state:sourceRange:)``
- ``Runtime/resume(runID:)``
- ``Runtime/assert(_:message:sourceRange:)``
- ``Runtime/complete(reason:sourceRange:)``

### State management

- ``State``
- ``Value``

### Tools

- ``ToolRegistry``
- ``ToolKind``
- ``RedactionPolicy``

### Events and observation

- ``Event``
- ``EventKind``
- ``Observer``
- ``JSONLObserver``
- ``InMemoryObserver``
- ``CompositeObserver``
- ``TraceTreeRenderer``

### Persistence

- ``Checkpointer``
- ``InMemoryCheckpointer``
- ``FilesystemCheckpointer``
- ``ResumeContext``

### Errors

- ``MeridianRuntimeError``
- ``ToolError``
