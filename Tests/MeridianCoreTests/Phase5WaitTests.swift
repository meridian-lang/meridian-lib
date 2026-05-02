import Testing
import Foundation
@testable import MeridianCore
@testable import MeridianRuntime

// MARK: - Wait source parsing tests

@Suite("StatementParser — wait source forms")
struct WaitSourceParseTests {

    private func parseWait(_ line: String) throws -> WaitStatementAST? {
        let src = line + "."
        let lines = IndentTokenizer().tokenize(src, file: "t.meridian")
        let block = try StatementParser(symbols: nil).parseBlock(lines.filter(\.isContent))
        guard case .wait(let w) = block.statements.first else { return nil }
        return w
    }

    @Test("wait 1 hour parses as duration")
    func waitDuration() throws {
        let w = try parseWait("wait 1 hour")
        guard case .duration(let v, let unit) = w?.condition else {
            Issue.record("Expected duration")
            return
        }
        #expect(v == 1.0)
        #expect(unit == .hour)
    }

    @Test("wait for signal parses signal name")
    func waitSignal() throws {
        let w = try parseWait(#"wait for signal "manual_review_complete""#)
        guard case .signal(let name) = w?.condition else {
            Issue.record("Expected signal, got \(String(describing: w?.condition))")
            return
        }
        #expect(name == "manual_review_complete")
    }

    @Test("wait for approval from parses approval with role")
    func waitApproval() throws {
        let w = try parseWait("wait for approval from the account manager")
        guard case .approval(_, let role) = w?.condition else {
            Issue.record("Expected approval, got \(String(describing: w?.condition))")
            return
        }
        #expect(role == "the account manager")
    }

    @Test("wait for event parses event id")
    func waitEvent() throws {
        let w = try parseWait(#"wait for event payment.confirmed"#)
        guard case .event(let id, let matching) = w?.condition else {
            Issue.record("Expected event, got \(String(describing: w?.condition))")
            return
        }
        #expect(id == "payment.confirmed")
        #expect(matching == nil)
    }

    @Test("wait for event ... matching parses predicate")
    func waitEventMatching() throws {
        let w = try parseWait(#"wait for event payment.confirmed matching order id is "o-1""#)
        guard case .event(let id, let matching) = w?.condition else {
            Issue.record("Expected event with matching")
            return
        }
        #expect(id == "payment.confirmed")
        #expect(matching != nil)
    }
}

// MARK: - Wait codegen tests

@Suite("SwiftEmitter — wait codegen")
struct WaitCodegenTests {

    private func emitter() -> SwiftEmitter {
        SwiftEmitter(options: .init(emitSourceLineComments: false))
    }

    private func emitWait(_ cond: WaitConditionIR) -> String {
        let ir = IRPrimitive.wait(WaitIR(condition: cond))
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: [ir]),
                            mode: .strict, sourceFile: "t.meridian")
        return emitter().emitFile(workflows: [wf])
    }

    @Test("wait duration emits runtime.wait(.duration(...))")
    func waitDurationCodegen() {
        let out = emitWait(.duration(.seconds(3600)))
        #expect(out.contains("try await runtime.wait(.duration(.seconds(3600)))"))
    }

    @Test("wait signal emits runtime.wait(.signal(...))")
    func waitSignalCodegen() {
        let out = emitWait(.signal("manual_review_complete"))
        #expect(out.contains(#"try await runtime.wait(.signal("manual_review_complete"))"#))
    }

    @Test("wait approval emits RoleRef(identifier:) not bare string")
    func waitApprovalCodegen() {
        let out = emitWait(.approval(of: .literal(.string("")), by: "account_manager"))
        #expect(out.contains("RoleRef(identifier: \"account_manager\")"),
                Comment(rawValue: "Expected RoleRef in:\n\(out)"))
        // Must NOT emit a bare string for the role — that would not compile.
        #expect(!out.contains(#", by: "account_manager""#))
    }

    @Test("wait event with no matching emits matching: nil")
    func waitEventNilMatching() {
        let out = emitWait(.event("order.shipped", matching: nil))
        #expect(out.contains(#"try await runtime.wait(.event("order.shipped", matching: nil))"#))
    }

    @Test("wait event with matching emits closure { _event in … }")
    func waitEventWithMatching() {
        let out = emitWait(.event("payment.confirmed", matching: .identifierRef(name: "isVerified")))
        #expect(out.contains("{ _event in"))
        #expect(out.contains("isVerified"))
    }
}
