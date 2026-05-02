import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - Phase 4 Golden Diff
//
// Phase 4 deliverable (docs/status.md):
//   "Generated Swift output is byte-for-byte stable against a checked-in
//    expected file. A drift triggers a test failure that surfaces a unified
//    diff so a reviewer can decide whether the change is intentional."
//
// The golden file is `examples/golden/order_processing_expected.swift`. To
// intentionally re-baseline (e.g. after a codegen feature) run the test with
// `MERIDIAN_REGEN_GOLDENS=1` set in the environment — the test then
// rewrites the golden in-place and passes.
//
// Domain-section structural anchors are checked separately so the test
// surfaces a useful failure message even if the byte diff is huge.

@Suite("Phase 4 Golden Diff — order_processing")
struct Phase4GoldenDiff {

    // MARK: - Repo navigation

    private func packageRoot() -> URL {
        var url = URL(fileURLWithPath: #file)
        while url.lastPathComponent != "meridian" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }

    private func examplesURL() -> URL { packageRoot().appendingPathComponent("examples") }
    private func goldenURL()  -> URL { examplesURL().appendingPathComponent("golden/order_processing_expected.swift") }

    private func loadFixturePair() throws -> (meridian: String, merconfig: String) {
        let dir = examplesURL()
        let mer = try String(contentsOf: dir.appendingPathComponent("order_processing.meridian"), encoding: .utf8)
        let cfg = try String(contentsOf: dir.appendingPathComponent("ecommerce.merconfig"),       encoding: .utf8)
        return (mer, cfg)
    }

    private func compile() throws -> String {
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

    // MARK: 1. Domain-section structural anchors
    //
    // Cheap to evaluate, surface clear errors before the byte diff fires.

    @Test("Domain section emits expected typed structs/enums")
    func emitsTypedDomain() throws {
        let swift = try compile()
        // Header + per-kind protocol/struct pair (kinds whose parent chain
        // bottoms out at `thing` get a `<KindName>Kind` protocol composing
        // `MeridianThing`, plus the conforming struct).
        #expect(swift.contains("// MARK: - Domain types"))
        #expect(swift.contains("public protocol OrderKind: MeridianThing {"))
        #expect(swift.contains("public struct Order: OrderKind {"))
        #expect(swift.contains("public protocol CustomerKind: PersonKind {"))
        #expect(swift.contains("public struct Customer: CustomerKind {"))
        #expect(swift.contains("public protocol LineItemKind: MeridianThing {"))
        #expect(swift.contains("public struct LineItem: LineItemKind {"))
        // Scalar kinds still collapse to a typealias — no protocol/struct.
        #expect(swift.contains("public typealias EmailAddress = String"))
    }

    @Test("Customer flattens Person ancestry")
    func customerFlattensPerson() throws {
        let swift = try compile()
        // Slice out the Customer struct body for targeted assertions; if the
        // struct can't be found at all we'd rather fail with a clear message
        // than panic on optional unwraps.
        guard let openRange = swift.range(of: "public struct Customer: CustomerKind {") else {
            Issue.record("Customer struct not found in generated output")
            return
        }
        let after = swift[openRange.upperBound...]
        guard let closeRange = after.range(of: "\n}") else {
            Issue.record("Customer struct closing brace not found")
            return
        }
        let body = after[..<closeRange.lowerBound]
        #expect(body.contains("public var name: String"))
        #expect(body.contains("public var email: String"))
        #expect(body.contains("public var phoneNumber: String"))
        #expect(body.contains("public var status: CustomerStatus"))
        #expect(body.contains("public var creditLimit: Money"))
    }

    @Test("`one of (...)` properties get top-level enums + .firstCase defaults")
    func enumsEmitted() throws {
        let swift = try compile()
        #expect(swift.contains("public enum OrderStatus: String, Hashable, Codable, Sendable {"))
        // Multi-word cases get an explicit raw value; single-word cases use
        // Swift's default rawValue == identifier behaviour.
        #expect(swift.contains("underReview = \"under review\""))
        #expect(swift.contains("public enum ApprovalVerdict: String, Hashable, Codable, Sendable {"))
        #expect(swift.contains("status: OrderStatus = .draft"))
    }

    @Test("Bare enum-case identifiers lower to .string(rawValue)")
    func enumCaseLowering() throws {
        let swift = try compile()
        #expect(swift.contains("MeridianComparison.eq(state.get(\"result.verdict\"), .string(\"invalid\"))"))
        #expect(swift.contains("MeridianComparison.eq(state.get(\"approval.verdict\"), .string(\"denied\"))"))
        #expect(swift.contains("MeridianComparison.eq(state.get(\"payment.status\"), .string(\"succeeded\"))"))
    }

    @Test("Workflow init uses typed Order + Customer parameters")
    func workflowInitTyped() throws {
        let swift = try compile()
        #expect(swift.contains("public init(runtime: Runtime, order: Order, customer: Customer)"))
    }

    // MARK: 2. Byte-for-byte golden diff

    @Test("generated Swift matches examples/golden/order_processing_expected.swift")
    func goldenMatch() throws {
        let actual = try compile()
        let golden = goldenURL()

        // Re-baseline knob: explicit opt-in via env var so CI doesn't silently
        // overwrite drift.
        if ProcessInfo.processInfo.environment["MERIDIAN_REGEN_GOLDENS"] != nil {
            try actual.write(to: golden, atomically: true, encoding: .utf8)
            return
        }

        let expected = try String(contentsOf: golden, encoding: .utf8)
        if actual == expected { return }

        // Build a minimal first-difference report so the test failure points
        // at a line, not 600 lines of context.
        let actualLines   = actual.split(separator: "\n", omittingEmptySubsequences: false)
        let expectedLines = expected.split(separator: "\n", omittingEmptySubsequences: false)
        var firstDiff: Int = -1
        for i in 0 ..< min(actualLines.count, expectedLines.count)
            where actualLines[i] != expectedLines[i] {
            firstDiff = i
            break
        }
        if firstDiff < 0 { firstDiff = min(actualLines.count, expectedLines.count) }
        let context = 3
        let lo = max(0, firstDiff - context)
        let hi = min(max(actualLines.count, expectedLines.count), firstDiff + context + 1)
        var report = "Golden diff at line \(firstDiff + 1):\n"
        for i in lo ..< hi {
            let a = i < actualLines.count   ? String(actualLines[i])   : "<EOF>"
            let e = i < expectedLines.count ? String(expectedLines[i]) : "<EOF>"
            if a == e {
                report += "  \(i + 1): \(a)\n"
            } else {
                report += "- \(i + 1): \(e)\n"
                report += "+ \(i + 1): \(a)\n"
            }
        }
        report += "\nTo accept: re-run with MERIDIAN_REGEN_GOLDENS=1"
        Issue.record(.init(rawValue: report))
    }
}
