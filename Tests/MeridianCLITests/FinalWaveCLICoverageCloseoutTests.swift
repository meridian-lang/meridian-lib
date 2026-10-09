import Foundation
import Testing
@testable import MeridianCLIKit
import MeridianCore
import MeridianRuntime

private let repoRoot = FileManager.default.currentDirectoryPath
private func ex(_ rel: String) -> String { repoRoot + "/" + rel }

@Suite("Final Wave CLI coverage closeout", .serialized)
struct FinalWaveCLICoverageCloseoutTests {

    // MARK: - ExplainSwiftCommand

    @Test("explain-swift prints sidecar-backed explanation")
    func explainSwiftHappy() throws {
        let mer = """
        To greet a customer:
          emit "hello".
        """
        let cfg = """
        === vocabulary ===
        A customer is a kind of thing.
        """
        let compiler = Compiler(options: .init(trace: .silent()))
        let compiled = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "greet.meridian")], vocabularies: [.init(name: "local", file: "local.merconfig", source: cfg)]))["greet.meridian"]!
        let model = compiled.model
        let swift = compiled.swift
        let t = TempDir()
        let swiftURL = t.write("greet.swift", swift)
        let sidecar = try IRSidecarEmitter().emit(
            workflows: model.workflows,
            verbalizer: Verbalizer(model: model, trace: .silent()),
            sourceFile: "greet.meridian",
            swiftFile: "greet.swift",
            sourceMap: Compiler.sourceMap(fromGeneratedSwift: swift)
        )
        _ = t.write("greet.meridian.ir.json", sidecar)

        let cmd = try ExplainSwiftCommand.parse([swiftURL.path])
        try cmd.run()
    }

    @Test("explain-swift rejects missing swift or sidecar")
    func explainSwiftValidation() {
        let cmd = try? ExplainSwiftCommand.parse(["/definitely/missing.swift"])
        guard let cmd else {
            Issue.record("parse failed")
            return
        }
        #expect(throws: (any Error).self) { try cmd.run() }

        let t = TempDir()
        let swiftURL = t.write("orphan.swift", "// swift")
        let cmd2 = try? ExplainSwiftCommand.parse([swiftURL.path])
        guard let cmd2 else {
            Issue.record("parse failed")
            return
        }
        #expect(throws: (any Error).self) { try cmd2.run() }
    }

    @Test("explain-swift honors explicit --sidecar")
    func explainSwiftExplicitSidecar() throws {
        let t = TempDir()
        let swiftURL = t.write("a.swift", "// x")
        let sidecarURL = t.write("custom.ir.json", #"{"version":1,"statements":[]}"#)
        let cmd = try ExplainSwiftCommand.parse([swiftURL.path, "--sidecar", sidecarURL.path])
        #expect(throws: (any Error).self) { try cmd.run() }
    }

    // MARK: - MCPCommand / MCPServeCommand

    @Test("MCP stdio transport round-trips framed messages")
    func mcpStdioTransportRoundTrip() throws {
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [:] as [String: Any],
        ]
        let payload = try JSONSerialization.data(withJSONObject: request)
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        inputPipe.fileHandleForWriting.write(Data("Content-Length: \(payload.count)\r\n\r\n".utf8))
        inputPipe.fileHandleForWriting.write(payload)
        inputPipe.fileHandleForWriting.closeFile()

        let read = try MCPStdioTransport.readMessage(from: inputPipe.fileHandleForReading)
        #expect(read?["method"] as? String == "initialize")

        let response = try MCPServer().handle(read ?? [:])
        try MCPStdioTransport.writeMessage(response, to: outputPipe.fileHandleForWriting)
        outputPipe.fileHandleForWriting.closeFile()
        let out = outputPipe.fileHandleForReading.readDataToEndOfFile()
        #expect(String(data: out, encoding: .utf8)?.contains("protocolVersion") == true)
    }

    @Test("MCPServeCommand --once handles one framed request")
    func mcpServeOnceCommand() async throws {
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 3,
            "method": "ping",
        ]
        let payload = try JSONSerialization.data(withJSONObject: request)
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        inputPipe.fileHandleForWriting.write(Data("Content-Length: \(payload.count)\r\n\r\n".utf8))
        inputPipe.fileHandleForWriting.write(payload)
        inputPipe.fileHandleForWriting.closeFile()

        let savedIn = dup(STDIN_FILENO)
        let savedOut = dup(STDOUT_FILENO)
        dup2(inputPipe.fileHandleForReading.fileDescriptor, STDIN_FILENO)
        dup2(outputPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        let cmd = try MCPServeCommand.parse(["--once"])
        try await cmd.run()

        dup2(savedIn, STDIN_FILENO)
        dup2(savedOut, STDOUT_FILENO)
        close(savedIn)
        close(savedOut)
        outputPipe.fileHandleForWriting.closeFile()

        let out = outputPipe.fileHandleForReading.readDataToEndOfFile()
        #expect(String(data: out, encoding: .utf8)?.contains("jsonrpc") == true)
    }

    // MARK: - TraceEvalCommand / TraceEvalRunner (in-process)

    @Test("trace-eval runner text and json formats")
    func traceEvalRunnerFormats() async throws {
        let t = TempDir()
        let fileURL = t.url.appendingPathComponent("events.jsonl")
        let store = try JSONLTraceStore(fileURL: fileURL)
        let base = Date(timeIntervalSince1970: 1_719_792_000)
        try await store.append(TraceRecord(
            id: "rec-1",
            at: base,
            ingestOrder: 1,
            run: "run-1",
            step: "deploy",
            skillName: "TraceEvalFlow",
            skillVersionHash: "v1",
            tag: .failed,
            subject: "deploy",
            payload: ["tool": .string("deploy")],
            payloadHash: try CanonicalJSON.sha256Hex(for: ["tool": .string("deploy")]),
            outcome: .failure
        ))
        let instant = ISO8601DateFormatter.meridianFormatter.string(from: base.addingTimeInterval(5))

        try await TraceEvalRunner.run(
            input: fileURL.path,
            expression: "the deploy step has ever failed",
            instant: instant,
            merconfig: [],
            format: .text,
            trace: .silent()
        )
        try await TraceEvalRunner.run(
            input: fileURL.path,
            expression: "the deploy step has ever failed",
            instant: instant,
            merconfig: [],
            format: .json,
            trace: .silent()
        )
    }

    @Test("trace-eval runner validation errors")
    func traceEvalRunnerValidation() async {
        await #expect(throws: (any Error).self) {
            try await TraceEvalRunner.run(
                input: "/nope/trace.jsonl",
                expression: "the deploy step has ever failed",
                instant: ISO8601DateFormatter.meridianFormatter.string(from: Date()),
                merconfig: [],
                format: .text,
                trace: .silent()
            )
        }
        await #expect(throws: (any Error).self) {
            try await TraceEvalRunner.run(
                input: ex("examples/order_processing.meridian"),
                expression: "the order is ready",
                instant: "not-a-date",
                merconfig: [],
                format: .text,
                trace: .silent()
            )
        }
    }

    @Test("trace-eval command parse wires through to runner")
    func traceEvalCommand() async throws {
        let t = TempDir()
        let fileURL = t.url.appendingPathComponent("events.jsonl")
        let store = try JSONLTraceStore(fileURL: fileURL)
        let base = Date(timeIntervalSince1970: 1_719_792_000)
        try await store.append(TraceRecord(
            id: "rec-1",
            at: base,
            ingestOrder: 1,
            run: "run-1",
            step: "deploy",
            skillName: "TraceEvalFlow",
            skillVersionHash: "v1",
            tag: .failed,
            subject: "deploy",
            payload: [:],
            payloadHash: "abc",
            outcome: .failure
        ))
        let instant = ISO8601DateFormatter.meridianFormatter.string(from: base.addingTimeInterval(1))
        let cmd = try TraceEvalCommand.parse([
            fileURL.path,
            "the deploy step has ever failed",
            "--at", instant,
            "--format", "json"
        ])
        try await cmd.run()
    }

    @Test("TraceEvalRunner helpers cover scope labels and instant parsing")
    func traceEvalRunnerHelpers() throws {
        #expect(TraceEvalRunner.traceScopeLabel(.currentRun) == "currentRun")
        #expect(TraceEvalRunner.traceScopeLabel(.acrossAllRuns) == "acrossAllRuns")
        #expect(TraceEvalRunner.traceScopeLabel(.acrossSkills) == "acrossSkills")

        let iso = ISO8601DateFormatter.meridianFormatter.string(from: Date(timeIntervalSince1970: 1_000))
        let parsed = try TraceEvalRunner.parseInstant(iso)
        #expect(parsed.timeIntervalSince1970 == 1_000)

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        let alt = try TraceEvalRunner.parseInstant(fallback.string(from: Date(timeIntervalSince1970: 2_000)))
        #expect(alt.timeIntervalSince1970 == 2_000)
    }

    @Test("TraceEvalRunner statistical replay and replay-plan errors")
    func traceEvalRunnerStatistical() async throws {
        let t = TempDir()
        let fileURL = t.url.appendingPathComponent("stats.jsonl")
        let store = try JSONLTraceStore(fileURL: fileURL)
        let base = Date(timeIntervalSince1970: 1_719_792_000)
        for (index, outcome) in [TraceOutcome.success, .success, .failure].enumerated() {
            try await store.append(TraceRecord(
                id: "rec-\(index)",
                at: base.addingTimeInterval(Double(index)),
                ingestOrder: index + 1,
                run: "run-\(index)",
                step: "deploy",
                skillName: "TraceEvalFlow",
                skillVersionHash: "v1",
                tag: outcome == .success ? .completed : .failed,
                subject: "deploy",
                payload: ["tool": .string("deploy")],
                payloadHash: try CanonicalJSON.sha256Hex(for: ["tool": .string("deploy")]),
                outcome: outcome
            ))
        }
        let merconfigURL = t.write("stats.merconfig", "=== trace ===\nsample floor: 2\n")
        let instant = ISO8601DateFormatter.meridianFormatter.string(from: base.addingTimeInterval(10))
        try await TraceEvalRunner.run(
            input: fileURL.path,
            expression: "across all runs, the deploy step succeeds in at least 50% of runs",
            instant: instant,
            merconfig: [merconfigURL.path],
            format: .json,
            trace: .silent()
        )

        await #expect(throws: (any Error).self) {
            _ = try TraceEvalRunner.makeReplayPlan(
                expression: "the order is ready",
                vocabularies: [],
                trace: .silent()
            )
        }
    }

    @Test("TraceEvalRunner rejects empty store and ambiguous runs")
    func traceEvalRunnerStoreErrors() async throws {
        let t = TempDir()
        let emptyURL = t.url.appendingPathComponent("empty.jsonl")
        _ = try JSONLTraceStore(fileURL: emptyURL)
        let instant = ISO8601DateFormatter.meridianFormatter.string(from: Date())
        await #expect(throws: (any Error).self) {
            try await TraceEvalRunner.run(
                input: emptyURL.path,
                expression: "the deploy step has ever failed",
                instant: instant,
                merconfig: [],
                format: .text,
                trace: .silent()
            )
        }

        let multiURL = t.url.appendingPathComponent("multi.jsonl")
        let store = try JSONLTraceStore(fileURL: multiURL)
        let base = Date(timeIntervalSince1970: 1_719_792_000)
        for run in ["run-a", "run-b"] {
            try await store.append(TraceRecord(
                id: "rec-\(run)",
                at: base,
                ingestOrder: 1,
                run: run,
                step: "deploy",
                skillName: "TraceEvalFlow",
                skillVersionHash: "v1",
                tag: .failed,
                subject: "deploy",
                payload: [:],
                payloadHash: "h",
                outcome: .failure
            ))
        }
        await #expect(throws: (any Error).self) {
            try await TraceEvalRunner.run(
                input: multiURL.path,
                expression: "the deploy step has ever failed",
                instant: ISO8601DateFormatter.meridianFormatter.string(from: base.addingTimeInterval(1)),
                merconfig: [],
                format: .text,
                trace: .silent()
            )
        }
    }
}
