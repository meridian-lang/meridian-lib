import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("ASTToIR+Statements/Bind/Commands coverage")
struct ASTToIRStatementsBindCommandsCoverageTests {

    private func makeIR() -> ASTToIR {
        ASTToIR(symbols: SymbolTable(trace: .silent()), sourceFile: "t.meridian", trace: .silent())
    }

    @Test("lowerStatement complete/commit/emit produce matching IR primitives")
    func lowerStatementTerminals() throws {
        let ir = makeIR()
        let complete = try ir.lowerStatement(
            .complete(CompleteStatementAST(reason: "done", sourceLine: 1)),
            mode: .strict,
            depth: 0
        )
        #expect(complete.count == 1)
        if case .complete(let c) = complete[0] {
            #expect(c.reason == "done")
        } else {
            Issue.record("expected complete")
        }

        let commit = try ir.lowerStatement(
            .commit(CommitStatementAST(label: "mid", sourceLine: 2)),
            mode: .strict,
            depth: 0
        )
        #expect(commit.count == 1)
        if case .commit(let c) = commit[0] {
            #expect(c.label == "mid")
        } else {
            Issue.record("expected commit")
        }

        let emit = try ir.lowerStatement(
            .emit(EmitStatementAST(
                eventID: "order.placed",
                payload: [("id", .literal(.string("1")))],
                sourceLine: 3
            )),
            mode: .strict,
            depth: 0
        )
        #expect(emit.count == 1)
        if case .emit(let e) = emit[0] {
            #expect(e.eventID == "order.placed")
        } else {
            Issue.record("expected emit")
        }
    }

    @Test("lowerBind lowers a literal let-binding")
    func lowerBindLiteral() throws {
        let ir = makeIR()
        let primitives = try ir.lowerBind(
            BindStatementAST(name: "total", value: .literal(.integer(3)), sourceLine: 1),
            mode: .strict,
            depth: 0
        )
        #expect(primitives.count == 1)
        if case .bind(let b) = primitives[0] {
            #expect(b.name == "total")
        } else {
            Issue.record("expected bind")
        }
    }

    @Test("lowerShellCommand interpolates {hole} expressions")
    func lowerShellCommandHole() throws {
        let ir = makeIR()
        let expr = try ir.lowerShellCommand("echo {name}", scope: ["name"], sourceLine: 1)
        guard case .interpolatedString(let segs) = expr else {
            Issue.record("expected interpolated string"); return
        }
        #expect(segs.count >= 2)
        #expect(segs.contains { if case .expression = $0 { return true } else { return false } })
    }

    @Test("lowerShellCommand without holes stays a string literal")
    func lowerShellCommandNoHoles() throws {
        let ir = makeIR()
        let expr = try ir.lowerShellCommand("echo hi", scope: [], sourceLine: 1)
        #expect({
            if case .literal(.string(let s)) = expr { return s == "echo hi" }
            return false
        }())
    }

    @Test("lowerShellCommand escapes double braces and leaves ${…} literal")
    func lowerShellCommandEscapesAndDollar() throws {
        let ir = makeIR()
        let escaped = try ir.lowerShellCommand("echo {{name}} ${HOME}", scope: ["name"], sourceLine: 1)
        #expect({
            if case .literal(.string(let s)) = escaped {
                return s.contains("{name}") && s.contains("${HOME}")
            }
            return false
        }())
    }

    @Test("lowerShellCommand leaves code-shaped and unclosed braces literal")
    func lowerShellCommandCodeShapedAndUnclosed() throws {
        let ir = makeIR()
        let braceExpansion = try ir.lowerShellCommand("echo {a,b}", scope: ["a", "b"], sourceLine: 1)
        #expect({
            if case .literal(.string(let s)) = braceExpansion { return s == "echo {a,b}" }
            return false
        }())
        let empty = try ir.lowerShellCommand("echo {}", scope: [], sourceLine: 1)
        #expect({
            if case .literal(.string(let s)) = empty { return s == "echo {}" }
            return false
        }())
        let digits = try ir.lowerShellCommand("echo {42}", scope: [], sourceLine: 1)
        #expect({
            if case .literal(.string(let s)) = digits { return s == "echo {42}" }
            return false
        }())
        let unclosed = try ir.lowerShellCommand("echo {open", scope: [], sourceLine: 1)
        #expect({
            if case .literal(.string(let s)) = unclosed { return s == "echo {open" }
            return false
        }())
    }

    @Test("lowerShellCommand quoted holes use shellEscapedExpression")
    func lowerShellCommandQuotedHole() throws {
        let ir = makeIR()
        let expr = try ir.lowerShellCommand(#"printf "{name}" {name}"#, scope: ["name"], sourceLine: 1)
        guard case .interpolatedString(let segs) = expr else {
            Issue.record("expected interpolated string"); return
        }
        #expect(segs.contains { if case .shellEscapedExpression = $0 { return true } else { return false } })
        #expect(segs.contains { if case .expression = $0 { return true } else { return false } })
    }

    @Test("lowerShellCommand out-of-scope hole raises commandHoleOutOfScope")
    func lowerShellCommandOutOfScope() throws {
        let ir = makeIR()
        do {
            _ = try ir.lowerShellCommand("echo {missing}", scope: ["order"], sourceLine: 3)
            Issue.record("expected out-of-scope error")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .commandHoleOutOfScope })
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("freeIdentifierRoots walks property access")
    func freeIdentifierRootsWalk() {
        let ir = makeIR()
        let roots = ir.freeIdentifierRoots(
            .propertyAccess(.identifierRef(name: "order"), propertyName: "id")
        )
        #expect(roots.contains("order"))
    }

    @Test("freeIdentifierRoots covers comparison/logical/relation/invocation/table/interpolated arms")
    func freeIdentifierRootsMatrix() {
        let ir = makeIR()
        let a = IRExpression.identifierRef(name: "a")
        let b = IRExpression.identifierRef(name: "b")
        #expect(Set(ir.freeIdentifierRoots(.comparison(a, .equal, b))) == ["a", "b"])
        #expect(Set(ir.freeIdentifierRoots(.logical(.and, [a, b]))) == ["a", "b"])
        #expect(Set(ir.freeIdentifierRoots(
            .relationTraversal(a, relationName: "owns", target: b)
        )) == ["a", "b"])
        #expect(ir.freeIdentifierRoots(
            .relationTraversal(a, relationName: "owns", target: nil)
        ) == ["a"])
        #expect(ir.freeIdentifierRoots(.invocation(InvokeIR(
            toolID: "t",
            arguments: [InvokeArg("x", a)]
        ))) == ["a"])
        #expect(ir.freeIdentifierRoots(.tableLookup(
            table: "prices",
            keyColumn: "sku",
            key: a,
            valueColumn: "price"
        )) == ["a"])

        let interpolated = IRExpression.interpolatedString([
            .literal("x"),
            .expression(a),
            .conditional(condition: b, then: [.literal("t")], otherwise: [.literal("o")]),
            .forEach(variable: "row", collection: .identifierRef(name: "xs"), body: [.literal("b")]),
            .formatted(.identifierRef(name: "d"), formatter: "iso"),
            .shellEscapedExpression(.identifierRef(name: "e")),
        ])
        #expect(Set(ir.freeIdentifierRoots(interpolated)) == ["a", "b", "xs", "d", "e"])
        #expect(ir.freeIdentifierRoots(.literal(.string("x"))).isEmpty)
        #expect(ir.freeIdentifierRoots(.nowExpression).isEmpty)
    }

    @Test("decamel expands camelCase for phrase substitution")
    func decamelHelper() {
        let ir = makeIR()
        let spaced = ir.decamel("totalAmount")
        #expect(spaced.lowercased().contains("total"))
        #expect(spaced.lowercased().contains("amount"))
    }
}
