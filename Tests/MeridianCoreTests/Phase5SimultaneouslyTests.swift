import Testing
@testable import MeridianCore

@Suite("Phase 5 — simultaneously")
struct Phase5SimultaneouslyTests {

    @Test("simultaneously parses each top-level body statement as a branch")
    func parseSimultaneously() throws {
        let source = """
        simultaneously:
          emit customer.loaded.
          emit credit.loaded.
        """
        let lines = IndentTokenizer().tokenize(source, file: "sim.meridian")
        let block = try StatementParser(symbols: nil).parseBlock(lines.filter(\.isContent))

        guard case .simultaneously(let sim) = block.statements.first else {
            Issue.record("Expected simultaneously statement")
            return
        }
        #expect(sim.branches.count == 2)
    }

    @Test("simultaneously lowers to SimultaneouslyIR")
    func lowerSimultaneously() throws {
        let source = """
        simultaneously:
          emit customer.loaded.
          emit credit.loaded.
        """
        let lines = IndentTokenizer().tokenize(source, file: "sim.meridian")
        let block = try StatementParser(symbols: nil).parseBlock(lines.filter(\.isContent))
        let ir = try ASTToIR(symbols: SymbolTable(), sourceFile: "sim.meridian")
            .lowerBlock(block, mode: .strict, depth: 0)

        guard case .simultaneously(let sim) = ir.statements.first else {
            Issue.record("Expected SimultaneouslyIR")
            return
        }
        #expect(sim.branches.count == 2)
        #expect(sim.branches.allSatisfy { $0.statements.count == 1 })
    }

    @Test("simultaneously emits a throwing task group")
    func emitSimultaneously() {
        let sim = IRPrimitive.simultaneously(SimultaneouslyIR(branches: [
            IRBlock(statements: [.emit(EmitIR(eventID: "customer.loaded"))]),
            IRBlock(statements: [.emit(EmitIR(eventID: "credit.loaded"))])
        ]))
        let wf = IRWorkflow(
            name: "load dependencies",
            parameters: [],
            body: IRBlock(statements: [sim]),
            mode: .strict,
            sourceFile: "sim.meridian"
        )

        let out = SwiftEmitter(options: .init(emitSourceLineComments: false))
            .emitFile(workflows: [wf])

        #expect(out.contains("withThrowingTaskGroup(of: Void.self)"))
        #expect(out.contains("group.addTask"))
        #expect(out.contains("try await group.waitForAll()"))
        #expect(out.contains("customer.loaded"))
        #expect(out.contains("credit.loaded"))
    }
}
