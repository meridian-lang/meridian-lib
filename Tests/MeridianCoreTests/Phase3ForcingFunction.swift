import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - Phase 3 Forcing Function
//
// Specification (10_BUILD_PLAN.md, Phase 3):
//   meridian compile examples/order_processing.meridian -o build/
//     → swift build -C build/   (codegen must be valid Swift)
//     → swift run order-processing > actual.jsonl
//     → diff actual.jsonl expected.jsonl
//
// This in-tree test owns the *first three* checkpoints. The "diff against
// goldens" step lives outside the test bundle (manual regression check).
//
// What we assert here:
//   1. The compiler accepts the example source pair without throwing.
//   2. There are no `_unresolved` placeholders left in the output — every
//      phrase invocation either inlined or routed to a workflow call.
//   3. Generated Swift contains the structural anchors a runnable file needs:
//      Constants, Instances, ProcessOrder, the recursive ProcessOrder call,
//      the within-duration helper, and the Value-aware comparison helpers.

@Suite("Phase 3 Forcing Function — order_processing.meridian")
struct Phase3ForcingFunction {

    // MARK: Source loaders

    private func examplesURL() -> URL {
        // Tests run with Package.swift's Tests folder as cwd; walk up to the
        // package root and into `examples/`.
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.appendingPathComponent("examples")
    }

    private func loadFixturePair() throws -> (meridian: String, merconfig: String) {
        let dir = examplesURL()
        let mer = try String(contentsOf: dir.appendingPathComponent("order_processing.meridian"), encoding: .utf8)
        let cfg = try String(contentsOf: dir.appendingPathComponent("ecommerce.merconfig"),       encoding: .utf8)
        return (mer, cfg)
    }

    // MARK: 1. End-to-end compile succeeds

    @Test("compile order_processing.meridian + ecommerce.merconfig succeeds")
    func compileSucceeds() throws {
        let (mer, cfg) = try loadFixturePair()
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(
                includeTimestamp: false,
                sourceFileName: "order_processing.meridian",
                emitSourceLineComments: false
            )
        )
        let out = try Compiler(options: opts).compile(
            meridianSource: mer,
            meridianFile: "order_processing.meridian",
            merconfigSource: cfg,
            merconfigFile: "ecommerce.merconfig"
        )
        #expect(out.contains("public struct ProcessOrder: MeridianWorkflow"))
    }

    // MARK: 2. No unresolved placeholders

    @Test("generated Swift has zero _unresolved placeholders")
    func noUnresolvedPlaceholders() throws {
        let out = try compiledSource()
        let unresolved = extractUnresolved(out)
        #expect(!out.contains("_unresolved"),
                Comment(rawValue: "Found _unresolved placeholder(s) — phrase resolution is incomplete:\n" + unresolved))
        #expect(!out.contains("/* unresolved:"))
    }

    // MARK: 3. Structural anchors

    @Test("generated Swift includes Constants + Instances structs")
    func emitsConstantsAndInstances() throws {
        let out = try compiledSource()
        #expect(out.contains("public struct Constants: Sendable {"))
        #expect(out.contains("public struct Instances: Sendable {"))
        #expect(out.contains("public let primaryMailer: Value = .record(["))
        #expect(out.contains("public let stripe: Value = .record(["))
    }

    @Test("recursive 'process the order' lowers to ProcessOrder().run()")
    func emitsWorkflowRecursion() throws {
        let out = try compiledSource()
        #expect(out.contains("try await ProcessOrder(runtime: runtime, order: order, customer: customer).run()"))
    }

    @Test("within-duration uses MeridianComparison.isWithin (no comment placeholder)")
    func emitsWithinDurationCall() throws {
        let out = try compiledSource()
        #expect(out.contains("MeridianComparison.isWithin"))
        #expect(!out.contains("/* withinDuration */"))
    }

    @Test("state.get comparisons route through Value-aware helpers")
    func emitsValueAwareComparisons() throws {
        let out = try compiledSource()
        // At least one each — covers ==, <, > seen in the example.
        #expect(out.contains("MeridianComparison.eq("))
        #expect(out.contains("MeridianComparison.lt(") || out.contains("MeridianComparison.gt("))
    }

    @Test("instance refs resolve to instances.X (not state.get)")
    func emitsInstanceReferences() throws {
        let out = try compiledSource()
        #expect(out.contains("Value.from(instances.primaryMailer)"))
        #expect(out.contains("Value.from(instances.stripe)"))
        #expect(!out.contains("state.get(\"primary mailer\")"))
        #expect(!out.contains("state.get(\"stripe\")"))
    }

    @Test("payload values wrap optionals (state.get … ?? .null) and literals (.string)")
    func emitsValueWrappedPayloads() throws {
        let out = try compiledSource()
        #expect(out.contains("?? .null"))
        // String literal → .string("…")
        #expect(out.contains(".string(\"validation_failed\")")
                || out.contains("\"reason\": \"validation_failed\""))
    }

    // MARK: Helpers

    private func compiledSource() throws -> String {
        let (mer, cfg) = try loadFixturePair()
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(
                includeTimestamp: false,
                sourceFileName: "order_processing.meridian",
                emitSourceLineComments: false
            )
        )
        return try Compiler(options: opts).compile(
            meridianSource: mer,
            meridianFile: "order_processing.meridian",
            merconfigSource: cfg,
            merconfigFile: "ecommerce.merconfig"
        )
    }

    /// Extract the offending lines so failures point at concrete unresolved phrases.
    private func extractUnresolved(_ source: String) -> String {
        source
            .components(separatedBy: "\n")
            .filter { $0.contains("_unresolved") }
            .joined(separator: "\n")
    }
}
