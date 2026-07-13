import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Runtime observability fault injection")
struct RuntimeObservabilityFaultInjectionTests {

    @Test("trace-store append failure records operational diagnostic with run id")
    func traceStoreAppendFailure() async throws {
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: InMemoryObserver(),
            traceStore: FailingAppendTraceStore(),
            runID: "append-fail-run",
            traceConfiguration: TraceConfiguration(storeFailurePolicy: .failClosed),
            traceSkillIdentity: TraceSkillIdentity(name: "demo", versionHash: "v1")
        )

        await #expect(throws: MeridianRuntimeError.self) {
            try await runtime.emit(event: "demo.event", payload: [:])
        }
        let diagnostics = await runtime.operationalDiagnostics()
        let match = diagnostics.first { $0.code == "trace-store.append" }
        #expect(match != nil)
        #expect(match?.runID == "append-fail-run")
    }

    @Test("observer failure records operational diagnostic with run id")
    func observerFailure() async throws {
        let failingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-rt-obs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: failingDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: failingDir) }
        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: failingDir.path)

        let observer = try JSONLObserver.file(failingDir.appendingPathComponent("events.jsonl"))
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            runID: "observer-fail-run",
            traceConfiguration: TraceConfiguration(storeFailurePolicy: .failClosed)
        )

        await #expect(throws: MeridianRuntimeError.self) {
            try await runtime.emit(event: "demo.event", payload: [:])
        }
        let diagnostics = await runtime.operationalDiagnostics()
        let match = diagnostics.first { $0.code == "observer.record" }
        #expect(match?.runID == "observer-fail-run")
    }

    @Test("corrupt checkpoint JSON surfaces decode warning and operational diagnostic")
    func corruptCheckpointJSON() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-rt-cp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let runDir = root.appendingPathComponent("resume-run", isDirectory: true)
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: runDir.appendingPathComponent("000000001.json"))

        let cp = try FilesystemCheckpointer(rootURL: root)
        let snap = StateSnapshot(bindings: ["x": AnyCodable(.string("ok"))])
        try await cp.write(Checkpoint(
            runID: "resume-run",
            sequence: 2,
            timestamp: Date(),
            label: "valid",
            stateSnapshot: snap,
            sourceRange: nil
        ))

        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            checkpointer: cp,
            runID: "resume-run"
        )

        let context = try await runtime.resume(runID: "resume-run")
        #expect(context.lastCheckpointLabel == "valid")

        let diagnostics = await runtime.operationalDiagnostics()
        #expect(diagnostics.contains { $0.code == "checkpoint.decode" && $0.runID == "resume-run" })

        let warnings = await observer.events.filter {
            $0.payload["event"] == .string("runtime.artifact.warning")
                && $0.payload["code"] == .string("checkpoint.decode")
        }
        #expect(!warnings.isEmpty)
    }

    @Test("resume with no valid checkpoint records checkpoint.resume diagnostic")
    func resumeWithoutCheckpoint() async throws {
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            checkpointer: InMemoryCheckpointer(),
            runID: "missing-cp-run"
        )

        await #expect(throws: MeridianRuntimeError.self) {
            try await runtime.resume(runID: "missing-cp-run")
        }
        let diagnostics = await runtime.operationalDiagnostics()
        #expect(diagnostics.contains { $0.code == "checkpoint.resume" && $0.runID == "missing-cp-run" })
    }

    @Test("tool dispatch failure records operational diagnostic")
    func toolDispatchFailure() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "boom", .closure { _ in
            throw ToolError.implementation(code: "boom.failed", message: "secret=api_key=supersecret", cause: nil)
        })
        let runtime = Runtime(toolRegistry: registry, runID: "tool-fail-run")

        await #expect(throws: (any Error).self) {
            try await runtime.invoke(tool: "boom", args: [:])
        }
        let diagnostics = await runtime.operationalDiagnostics()
        let match = diagnostics.first { $0.code == "tool.dispatch" }
        #expect(match?.runID == "tool-fail-run")
        #expect(match?.message.contains("<redacted>") == true)
        #expect(match?.message.contains("supersecret") == false)

        let observer = InMemoryObserver()
        let observedRuntime = Runtime(toolRegistry: registry, observer: observer, runID: "tool-fail-run")
        await #expect(throws: (any Error).self) {
            try await observedRuntime.invoke(tool: "boom", args: [:])
        }
        let invokeError = await observer.events.first { $0.kind == .invokeError }
        if case .string(let errorText) = invokeError?.payload["error"] {
            #expect(errorText.contains("<redacted>") == true)
            #expect(errorText.contains("supersecret") == false)
        } else {
            Issue.record("expected invoke.error payload with redacted error text")
        }
    }

    @Test("operational diagnostics redact bearer tokens in messages")
    func operationalDiagnosticRedaction() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "boom", .closure { _ in
            throw ToolError.implementation(
                code: "auth.failed",
                message: "Authorization: Bearer abc.def.ghi",
                cause: nil
            )
        })
        let runtime = Runtime(toolRegistry: registry, runID: "redact-run")
        await #expect(throws: (any Error).self) {
            try await runtime.invoke(tool: "boom", args: [:])
        }
        let diagnostic = await runtime.operationalDiagnostics().first { $0.code == "tool.dispatch" }
        #expect(diagnostic?.message.contains("<redacted>") == true)
        #expect(diagnostic?.message.contains("abc.def.ghi") == false)
    }

    @Test("ShellHoleRedaction and WitnessCapture still redact sensitive payloads")
    func shellAndWitnessRedaction() throws {
        let shellArgs = ShellHoleRedaction.redactInvokeArgs(
            toolID: "shell.run",
            args: ["command": .string("curl -H 'Authorization: Bearer token123'")],
            capturePolicy: nil
        )
        #expect(shellArgs["command"] == .string("<redacted>"))

        let witness = try WitnessCapture.buildEnvelope(
            body: ["password": .string("hunter2"), "status": .string("failed")],
            mode: .redacted
        )
        #expect(witness.body?["password"] == .string("<redacted>"))
    }

    @Test("torn trace JSONL line surfaces trace-store.read warning through runtime evaluate")
    func tornTraceLineWarning() async throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-rt-trace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let fileURL = tempRoot.appendingPathComponent("trace.jsonl")
        let store = try JSONLTraceStore(fileURL: fileURL)
        try await store.append(TraceRecord(
            id: "r1",
            at: Date(timeIntervalSince1970: 1),
            ingestOrder: 1,
            run: "trace-warn-run",
            step: "deploy",
            skillName: "deploy",
            skillVersionHash: "v1",
            tag: .completed,
            subject: "deploy",
            payload: [:],
            payloadHash: "payload",
            outcome: .success,
            witness: nil,
            previousHash: nil,
            recordHash: nil,
            operationalDetail: nil,
            legacyKind: nil
        ))

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("{\"broken\":".utf8))
            try handle.close()
        }

        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            traceStore: try JSONLTraceStore(fileURL: fileURL),
            runID: "trace-warn-run",
            traceConfiguration: TraceConfiguration(sampleFloor: 1),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )

        _ = try await runtime.evaluateTrace(
            TraceTemporalQuery(kind: .ever(
                TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded))),
            evaluationInstant: Date(timeIntervalSince1970: 10)
        )

        let diagnostics = await runtime.operationalDiagnostics()
        #expect(diagnostics.contains { $0.code == "trace-store.read" })
        let warnings = await observer.events.filter {
            $0.payload["code"] == .string("trace-store.read")
        }
        #expect(!warnings.isEmpty)
    }
}

private actor FailingAppendTraceStore: TraceStore {
    var capabilities: TraceStoreCapabilities {
        TraceStoreCapabilities(
            isPersistent: false,
            supportsHashChaining: false,
            supportsCompaction: false,
            indexedFields: [],
            supportedSchemaVersions: [1])
    }

    func append(_ event: TraceRecord) async throws {
        throw TraceStoreError.traceStoreFailure("simulated append failure")
    }

    func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] { [] }

    func compact(retention: Duration, now: Date) async throws {}

    func verifyChain(runID: String) async throws -> TraceChainVerificationResult {
        TraceChainVerificationResult(runID: runID, verifiedCount: 0, isValid: true, failure: nil)
    }
}
