import Testing
@testable import MeridianCore

@Suite("Autonomy mode")
struct AutonomyModeTests {

    @Test("AutonomyConfigAST parses every centralized option marker")
    func autonomyConfigMarkers() {
        let config = AutonomyConfigAST.parse(
            "until ci is passed unless blocked replan after 4 failures up to 9 steps",
            parseExpression: { ExpressionParser(trace: .silent()).parse($0) }
        )

        #expect(config.until != nil)
        #expect(config.unless != nil)
        #expect(config.replanAfterFailures == 4)
        #expect(config.maxSteps == 9)

        let hyphenated = AutonomyConfigAST.parse(
            "re-plan after 2 failures max 5 steps",
            parseExpression: { ExpressionParser(trace: .silent()).parse($0) }
        )
        #expect(hyphenated.replanAfterFailures == 2)
        #expect(hyphenated.maxSteps == 5)
    }

    @Test("a clause with nothing but whitespace before the next boundary marker is dropped, not blank-parsed")
    func emptyClauseTextIsDropped() {
        // Two spaces between "until" and "unless" leave nothing but
        // whitespace for the `until` clause once the next boundary marker is
        // found — `clause(_:)` must trim that to empty and return `nil`
        // rather than handing `parseExpression` a blank string.
        let config = AutonomyConfigAST.parse(
            "until  unless blocked",
            parseExpression: { ExpressionParser(trace: .silent()).parse($0) }
        )
        #expect(config.until == nil)
        #expect(config.unless != nil)
    }

    @Test("autonomy workflow header records stop and replan clauses")
    func parsesAutonomyHeader() throws {
        let ast = try MeridianParser(symbols: SymbolTable(), trace: .silent()).parse("""
        To stabilize, with autonomy until ci is passed unless blocked re-plan after 2 failures:
          keep fixing the smallest failing thing.
        """)

        let autonomy = try #require(ast.workflows[0].autonomy)
        #expect(autonomy.replanAfterFailures == 2)
        #expect(autonomy.until != nil)
        #expect(autonomy.unless != nil)
    }

    @Test("unmatched autonomy body lowers to autonomous AIAutonomyIR")
    func lowersAutonomyProseStep() throws {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To stabilize, with autonomy re-plan after 2 failures:
          keep fixing the smallest failing thing.
        """)
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)

        guard case .aiAutonomy(let step) = workflows[0].body.statements.first else {
            Issue.record("Expected autonomous AIAutonomyIR")
            return
        }
        #expect(step.autonomy.replanAfterFailures == 2)
    }

    @Test("AIAutonomyIR emits executeAutonomousLoop")
    func autonomyCodegen() throws {
        let workflow = IRWorkflow(
            name: "Stabilize",
            parameters: [],
            body: IRBlock(statements: [
                .aiAutonomy(AIAutonomyIR(
                    text: "keep fixing",
                    scopedTools: ["ci.fix"],
                    autonomy: AutonomyConfigIR(
                        until: .comparison(.identifierRef(name: "done"), .equal, .literal(.boolean(true))),
                        unless: .comparison(.identifierRef(name: "blocked"), .equal, .literal(.boolean(true))),
                        replanAfterFailures: 2,
                        maxSteps: 5
                    )
                ))
            ])
        )

        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: [workflow])
        #expect(out.contains("runtime.executeAutonomousLoop"))
        #expect(out.contains("replanAfterFailures: 2"))
        #expect(out.contains("maxSteps: 5"))
        #expect(out.contains("until: { __meridianAutonomySnapshot in"))
        #expect(out.contains("unless: { __meridianAutonomySnapshot in"))
        #expect(out.contains("state.restore(from: __meridianAutonomySnapshot)"))
    }
}
