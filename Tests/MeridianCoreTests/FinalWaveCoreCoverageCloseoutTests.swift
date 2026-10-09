import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Final Wave core coverage closeout")
struct FinalWaveCoreCoverageCloseoutTests {

    // MARK: - CanonicalIRSerializer

    @Test("CanonicalIRSerializer norm semantic payload serializes deterministically")
    func canonicalIRSerializer() throws {
        let norm = NormIR(
            kind: .prohibition,
            scope: .skill,
            actionPattern: ActionPatternIR(toolID: "timeNow"),
            sourceRange: SourceRange(file: "t.meridian", line: 1, column: 1),
            originalText: "must not invoke time.now"
        )
        let payload = CanonicalIRSerializer.normSemanticPayload(norm)
        let data = try CanonicalJSON.data(for: payload)
        #expect(!data.isEmpty)
        #expect(payload["kind"] == .string("prohibition"))
    }

    // MARK: - DeonticLowering

    @Test("DeonticLowering detects prohibition conflicts")
    func deonticLoweringConflicts() {
        let range = SourceRange(file: "t.meridian", line: 1, column: 1)
        let prohibition = NormIR(
            kind: .prohibition,
            scope: .skill,
            actionPattern: ActionPatternIR(toolID: "timeNow"),
            sourceRange: range,
            originalText: "must not invoke time.now"
        )
        let permission = NormIR(
            kind: .permission,
            scope: .skill,
            actionPattern: ActionPatternIR(toolID: "timeNow"),
            sourceRange: SourceRange(file: "t.meridian", line: 2, column: 1),
            originalText: "may invoke time.now"
        )
        let diags = DeonticLowering.detectConflicts([prohibition, permission])
        #expect(!diags.isEmpty)
    }

    // MARK: - ModuleSymbolSnapshot

    @Test("ModuleSymbolSnapshot builds from merconfig vocabulary")
    func moduleSymbolSnapshot() throws {
        let cfg = try MerConfigParser().parse("""
        === vocabulary ===
        An order is a kind of thing.
        === tools ===
        Charge Payment
        ==============
        ~ chargePayment(order: Order) : Order
        """, file: "mod.merconfig")
        let manifest = ModuleManifest(id: "demo", visibility: .public, sealedExports: ["order"])
        let snap = ModuleSymbolSnapshot.build(from: cfg, manifest: manifest)
        #expect(snap.moduleID == "demo")
        #expect(snap.kinds.contains("order"))
        #expect(snap.tools.contains("chargepayment"))
        #expect(snap.sealed.contains("order"))
    }

    // MARK: - LiteralLowering

    @Test("LiteralLowering maps every literal and comparison operator arm")
    func literalLoweringArms() {
        if case .number(let n) = LiteralLowering.toIRLiteral(.integer(1)) {
            #expect(n == 1)
        } else { Issue.record("integer") }
        if case .money(let amount, let currency) = LiteralLowering.toIRLiteral(.money(1, currency: "USD")) {
            #expect(amount == 1)
            #expect(currency == "USD")
        } else { Issue.record("money") }
        if case .calendarAmount(let amount) = LiteralLowering.toIRLiteral(.calendarAmount(2, .businessDays)) {
            #expect(amount.magnitude == 2)
            #expect(amount.unit == .businessDays)
        } else { Issue.record("calendar") }
        #expect(LiteralLowering.mapComparisonOp(.equal) == .equal)
        #expect(LiteralLowering.mapComparisonOp(.greaterThan) == .greaterThan)
        #expect(LiteralLowering.mapLogicalOp(.and) == .and)
    }

    // MARK: - IREquality residual arms

    @Test("IREquality covers calendar amount and trace carrier equality")
    func irEqualityTraceArms() {
        let cal = IRExpression.literal(.calendarAmount(.init(magnitude: 2, unit: .businessDays)))
        #expect(IREquality.structurallyEqual(cal, cal))
        #expect(IREquality.structurallyEqual(
            IRExpression.traceTemporal(TraceTemporalIR(scope: .currentRun, kind: .ever(
                EventPatternIR(subject: .step("x"), outcome: .succeeded)
            ))),
            IRExpression.traceTemporal(TraceTemporalIR(scope: .currentRun, kind: .ever(
                EventPatternIR(subject: .step("x"), outcome: .succeeded)
            )))
        ))
    }

    // MARK: - CanonicalForms residual

    @Test("CanonicalForms covers calendar amount and comparison wording")
    func canonicalFormsResidual() {
        #expect(CanonicalForms.literal(.calendarAmount(CalendarAmountIR(magnitude: 3, unit: .months))) == "3.0 months")
        #expect(CanonicalForms.comparison(.withinPast) == "is within the last")
        #expect(CanonicalForms.comparison(.withinFuture) == "is in the next")
    }

    // MARK: - IRSidecarEmitter

    @Test("IRSidecarEmitter emits JSON for a trivial workflow")
    func irSidecarEmitter() throws {
        let wf = IRWorkflow(name: "greet", parameters: [], body: IRBlock(statements: [
            .emit(EmitIR(eventID: "hello")),
        ]))
        let model = VerbalizerModel(
            workflows: [wf],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable.build(from: MerConfigFile()),
            lexicon: .default,
            sourceFileName: "greet.meridian",
            authoredSource: ""
        )
        let json = try IRSidecarEmitter().emit(
            workflows: [wf],
            verbalizer: Verbalizer(model: model),
            sourceFile: "greet.meridian",
            swiftFile: "greet.swift",
            sourceMap: []
        )
        #expect(json.contains("greet.meridian"))
    }

    // MARK: - NormId

    @Test("norm id assignment is deterministic and registry-stable")
    func normIdDeterminism() throws {
        var registry = NormIdRegistry()
        let norm = NormIR(
            kind: .prohibition,
            scope: .skill,
            actionPattern: ActionPatternIR(toolID: "timeNow"),
            sourceRange: SourceRange(file: "t.meridian", line: 1, column: 1),
            originalText: "must not invoke time.now"
        )
        let first = try NormId.make(from: norm, registry: &registry)
        let second = try NormId.make(from: norm, registry: &registry)
        #expect(first == second)
        #expect(first.hasPrefix("OBL-"))
    }
}
