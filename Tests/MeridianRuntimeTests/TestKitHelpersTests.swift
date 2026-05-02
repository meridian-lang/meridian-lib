import Testing
import Foundation
@testable import MeridianTestKit
import MeridianRuntime

@Suite("MeridianTestKit helpers")
struct TestKitHelpersTests {
    @Test("RecordingTool captures calls and returns configured value")
    func recordingTool() async throws {
        let tool = RecordingTool(return: .string("ok"))
        let result = try await tool.handler(["x": .number(1)])
        #expect(result == .string("ok"))
        let calls = await tool.recordedCalls()
        #expect(calls.count == 1)
        #expect(calls.first?.args["x"] == .number(1))
    }

    @Test("MockToolRegistry stubs a tool")
    func mockToolRegistry() async throws {
        let mock = MockToolRegistry()
        await mock.stub("answer", return: .number(42))
        let result = try await mock.registry.dispatch(tool: "answer", args: [:])
        #expect(result == .number(42))
    }

    @Test("MockRuntime exposes a runtime with stubbed tools")
    func mockRuntime() async throws {
        let mock = await MockRuntime(runID: "mock")
        await mock.stub(tool: "echo", return: .string("hi"))
        let result = try await mock.runtime.invoke(tool: "echo", args: [:])
        #expect(result == .string("hi"))
    }

    @Test("GoldenFile normalizes newline and trailing whitespace")
    func goldenFileNormalize() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("golden-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let golden = GoldenFile(url)
        try "hello\n".write(to: url, atomically: true, encoding: .utf8)
        #expect(try golden.assertMatches("hello\r\n\n") == true)
    }
}
