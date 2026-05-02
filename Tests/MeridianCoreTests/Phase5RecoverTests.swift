import Testing
import Foundation
@testable import MeridianCore
@testable import MeridianRuntime

// MARK: - Recover parser tests

@Suite("StatementParser — recover from")
struct RecoverParserTests {

    private func parse(_ source: String) throws -> ASTBlock {
        let lines = IndentTokenizer().tokenize(source, file: "test.meridian")
        return try StatementParser(symbols: nil).parseBlock(lines.filter(\.isContent))
    }

    @Test("recover from any: parses and attaches to preceding statement")
    func recoverAny() throws {
        let src = """
        complete with reason "done".
        recover from any:
          complete with reason "fallback".
        """
        let block = try parse(src)
        // After attachment the block should have one top-level statement: the recover.
        guard case .recover(let rec) = block.statements.last else {
            Issue.record("Expected recover statement, got \(block.statements)")
            return
        }
        guard case .any = rec.pattern else {
            Issue.record("Expected .any pattern, got \(rec.pattern)")
            return
        }
        guard case .complete = rec.attached else {
            Issue.record("Expected complete as attached, got \(rec.attached)")
            return
        }
        #expect(rec.handler.statements.count == 1)
    }

    @Test("recover from named pattern")
    func recoverNamed() throws {
        let src = """
        complete.
        recover from payment.declined:
          complete with reason "declined".
        """
        let block = try parse(src)
        guard case .recover(let rec) = block.statements.last else {
            Issue.record("Expected recover statement")
            return
        }
        guard case .named(let n) = rec.pattern else {
            Issue.record("Expected .named")
            return
        }
        #expect(n == "payment.declined")
    }

    @Test("recover from typed pattern (capitalised identifier)")
    func recoverTyped() throws {
        let src = """
        complete.
        recover from TimeoutError:
          complete with reason "timed_out".
        """
        let block = try parse(src)
        guard case .recover(let rec) = block.statements.last else {
            Issue.record("Expected recover")
            return
        }
        guard case .typed(let t) = rec.pattern else {
            Issue.record("Expected .typed, got \(rec.pattern)")
            return
        }
        #expect(t == "TimeoutError")
    }

    @Test("recover where predicate")
    func recoverPredicate() throws {
        let src = """
        complete.
        recover where the amount is more than 100:
          complete with reason "large_error".
        """
        let block = try parse(src)
        guard case .recover(let rec) = block.statements.last else {
            Issue.record("Expected recover")
            return
        }
        guard case .predicate = rec.pattern else {
            Issue.record("Expected .predicate, got \(rec.pattern)")
            return
        }
        #expect(rec.handler.statements.count == 1)
    }

    @Test("chained recovers nest outward")
    func recoverChained() throws {
        let src = """
        complete.
        recover from payment.declined:
          complete with reason "declined".
        recover from any:
          complete with reason "other_error".
        """
        let block = try parse(src)
        // The outer recover attaches to the inner recover.
        guard block.statements.count == 1 else {
            Issue.record("Expected 1 top-level statement (nested recover), got \(block.statements.count)")
            return
        }
        guard case .recover(let outer) = block.statements[0] else {
            Issue.record("Expected recover")
            return
        }
        guard case .any = outer.pattern else {
            Issue.record("Expected outer .any")
            return
        }
        // The attached statement of the outer recover is the inner recover.
        guard case .recover(let inner) = outer.attached else {
            Issue.record("Expected inner recover attached")
            return
        }
        guard case .named = inner.pattern else {
            Issue.record("Expected inner .named")
            return
        }
    }

    @Test("recover as first statement (no preceding) uses placeholder attached")
    func recoverOrphan() throws {
        let src = """
        recover from any:
          complete with reason "orphan".
        """
        let block = try parse(src)
        // No preceding statement — the attached field will be the placeholder.
        guard case .recover(let rec) = block.statements.last else {
            Issue.record("Expected recover")
            return
        }
        // Attached is the placeholder phrase invocation injected by the parser.
        if case .phraseInvocation(let pi) = rec.attached {
            #expect(pi.words == "__recover_placeholder__")
        }
    }
}

// MARK: - Recover lowering tests

@Suite("ASTToIR — recover lowering")
struct RecoverLoweringTests {

    private func lower(_ source: String) throws -> [IRPrimitive] {
        let cfg = ""
        let voc = Compiler.VocabularyInput(name: "test", file: "test.merconfig", source: cfg)
        let opts = Compiler.Options(emitterOptions: SwiftEmitter.Options(emitSourceLineComments: false))
        // Build a minimal SymbolTable for standalone lowering.
        let symbols = SymbolTable()
        let lines = IndentTokenizer().tokenize(source, file: "test.meridian")
        let parser = StatementParser(symbols: symbols)
        let block = try parser.parseBlock(lines.filter(\.isContent))
        let lowerer = ASTToIR(symbols: symbols, sourceFile: "test.meridian")
        return try lowerer.lowerBlock(block, mode: .strict, depth: 0).statements
    }

    @Test("recover from any: lowers to RecoverIR with anyError pattern")
    func lowerAny() throws {
        let source = """
        complete.
        recover from any:
          complete with reason "err".
        """
        let prims = try lower(source)
        guard case .recover(let rec) = prims.last else {
            Issue.record("Expected recover IR")
            return
        }
        guard case .anyError = rec.pattern else {
            Issue.record("Expected anyError pattern")
            return
        }
        #expect(rec.handler.statements.count == 1)
        #expect(rec.attachedTo.statements.count >= 1)
    }

    @Test("recover from named lowers to .named ErrorPattern")
    func lowerNamed() throws {
        let source = """
        complete.
        recover from payment.declined:
          complete with reason "declined".
        """
        let prims = try lower(source)
        guard case .recover(let rec) = prims.last else {
            Issue.record("Expected recover IR")
            return
        }
        guard case .named(let n) = rec.pattern else {
            Issue.record("Expected named")
            return
        }
        #expect(n == "payment.declined")
    }

    @Test("recover from typed lowers to .typed ErrorPattern")
    func lowerTyped() throws {
        let source = """
        complete.
        recover from TimeoutError:
          complete with reason "timeout".
        """
        let prims = try lower(source)
        guard case .recover(let rec) = prims.last else {
            Issue.record("Expected recover IR")
            return
        }
        guard case .typed(let k) = rec.pattern else {
            Issue.record("Expected typed")
            return
        }
        #expect(k.name == "TimeoutError")
    }
}

// MARK: - Recover codegen tests

@Suite("SwiftEmitter — recover codegen")
struct RecoverCodegenTests {

    private func emitter() -> SwiftEmitter {
        SwiftEmitter(options: .init(emitSourceLineComments: false))
    }

    @Test("recover from any emits do { } catch let _recoveredError {}")
    func emitAny() {
        let ir = IRPrimitive.recover(RecoverIR(
            pattern: .anyError,
            handler: IRBlock(statements: [.complete(CompleteIR(reason: "err"))]),
            attachedTo: IRBlock(statements: [.complete(CompleteIR(reason: "ok"))])
        ))
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: [ir]),
                            mode: .strict, sourceFile: "test.meridian")
        let out = emitter().emitFile(workflows: [wf])
        #expect(out.contains("do {"))
        #expect(out.contains("} catch let _recoveredError {"))
    }

    @Test("recover from named emits meridianMatches(_:named:) where clause")
    func emitNamed() {
        let ir = IRPrimitive.recover(RecoverIR(
            pattern: .named("payment.declined"),
            handler: IRBlock(statements: [.complete(CompleteIR(reason: "declined"))]),
            attachedTo: IRBlock(statements: [.complete(CompleteIR(reason: "charged"))])
        ))
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: [ir]),
                            mode: .strict, sourceFile: "test.meridian")
        let out = emitter().emitFile(workflows: [wf])
        #expect(out.contains("meridianMatches(_recoveredError, named: \"payment.declined\")"),
                Comment(rawValue: "Expected meridianMatches in:\n\(out)"))
        // Must not use the old non-existent isNamed call.
        #expect(!out.contains("isNamed("))
    }

    @Test("recover from typed emits `catch let _recoveredError as TypeName`")
    func emitTyped() {
        let ir = IRPrimitive.recover(RecoverIR(
            pattern: .typed(KindRef("TimeoutError")),
            handler: IRBlock(statements: [.complete(CompleteIR(reason: "timeout"))]),
            attachedTo: IRBlock(statements: [.complete(CompleteIR(reason: "ok"))])
        ))
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: [ir]),
                            mode: .strict, sourceFile: "test.meridian")
        let out = emitter().emitFile(workflows: [wf])
        #expect(out.contains("catch let _recoveredError as TimeoutError"))
    }

    @Test("recover from predicate emits where clause with emitted expression")
    func emitPredicate() {
        let ir = IRPrimitive.recover(RecoverIR(
            pattern: .predicate(.identifierRef(name: "isRetryable")),
            handler: IRBlock(statements: [.complete(CompleteIR(reason: "retry"))]),
            attachedTo: IRBlock(statements: [.complete(CompleteIR(reason: "ok"))])
        ))
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: [ir]),
                            mode: .strict, sourceFile: "test.meridian")
        let out = emitter().emitFile(workflows: [wf])
        #expect(out.contains("let _recoveredError where"))
        #expect(out.contains("isRetryable"))
    }
}

// MARK: - meridianMatches helper tests

@Suite("meridianMatches error matching")
struct MeridianMatchesTests {

    @Test("matches ToolError.implementation by code")
    func matchesToolErrorByCode() {
        let err = ToolError.implementation(code: "payment.declined", message: "card declined", cause: nil)
        #expect(meridianMatches(err, named: "payment.declined"))
        #expect(!meridianMatches(err, named: "payment.expired"))
    }

    @Test("matches MeridianRuntimeError.approvalDenied by role")
    func matchesApprovalDeniedByRole() {
        let err = MeridianRuntimeError.approvalDenied(role: "account_manager", sourceRange: nil)
        #expect(meridianMatches(err, named: "approval.denied"))
        #expect(meridianMatches(err, named: "account_manager"))
        #expect(!meridianMatches(err, named: "supervisor"))
    }

    @Test("does not match unrelated errors")
    func noMatchUnrelated() {
        let err = MeridianRuntimeError.cancelled
        #expect(!meridianMatches(err, named: "payment.declined"))
    }

    @Test("meridianMatches typed matches on exact dynamic type")
    func matchesTyped() {
        let toolErr = ToolError.timeout(.seconds(30))
        #expect(meridianMatches(toolErr, typed: ToolError.self))
        #expect(!meridianMatches(toolErr, typed: MeridianRuntimeError.self))
    }
}
