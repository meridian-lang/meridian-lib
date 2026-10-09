import Foundation
import MeridianRuntime

/// Normalizes an IR value so plain `==` reproduces `IREquality`'s structural
/// semantics exactly: identifier-like fields are case/article/punctuation
/// folded, string literals are unescaped, AI prose is line-normalized, and
/// provenance-only fields (`sourceRange`, `stableStepPath`, progress labels)
/// collapse to a canonical value. Fields `IREquality` deliberately does not
/// compare (e.g. `AssertIR.message`, `EventPatternIR.negated`,
/// `TraceStatisticalIR.confidencePercent`) collapse too, so that
/// `normalized(a) == normalized(b)` holds iff `IREquality.structurallyEqual(a, b)`.
///
/// The per-field choice of identifier folding vs. plain comparison mirrors
/// `IREquality` overload by overload; it is not a free-standing policy.
enum IRNormalizer {
    // MARK: - Scalar folding

    /// Lowercase, split on non-alphanumerics, drop empties and articles, join.
    /// IR structural equality is lexicon-agnostic; use the default English
    /// article set rather than re-listing surface vocabulary inline.
    static func normalizeIdentifier(_ value: String) -> String {
        let articles = EnglishLexicon.default.articles
        let words = value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !articles.contains($0) }
        return words.joined()
    }

    static func normalizeStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }

    /// Trim each line, drop a leading `- ` bullet, drop trailing `:`, rejoin.
    static func normalizeAIText(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { line in
                var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("- ") {
                    trimmed = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                while trimmed.hasSuffix(":") {
                    trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return trimmed
            }
            .joined(separator: "\n")
    }

    // MARK: - Workflow-level

    static func normalized(_ a: IRWorkflow) -> IRWorkflow {
        // `structName` is compared (identifier-folded) while `explicitStructName`
        // is not, so the folded `structName` is re-pinned as the explicit name.
        IRWorkflow(
            name: normalizeIdentifier(a.name),
            parameters: a.parameters.map(normalized),
            body: normalized(a.body),
            mode: a.mode,
            sourceFile: "",
            sourceRange: .unknown,
            explicitStructName: normalizeIdentifier(a.structName),
            allowsDiscretion: a.allowsDiscretion,
            skillName: "",
            skillVersionHash: "",
            runtimeTraceConfiguration: nil,
            norms: a.norms.map(normalized)
        )
    }

    static func normalized(_ a: IRBlock) -> IRBlock {
        IRBlock(statements: a.statements.map(normalized), sourceRange: .unknown)
    }

    static func normalized(_ a: IRParameter) -> IRParameter {
        IRParameter(name: normalizeIdentifier(a.name), kind: KindRef(normalizeIdentifier(a.kind.name)))
    }

    static func normalized(_ a: LoweredDefinition) -> LoweredDefinition {
        LoweredDefinition(
            functionName: normalizeIdentifier(a.functionName),
            subjectVar: normalizeIdentifier(a.subjectVar),
            body: normalized(a.body)
        )
    }

    // MARK: - Primitives

    static func normalized(_ a: IRPrimitive) -> IRPrimitive {
        switch a {
        case .invoke(let ir):
            return .invoke(InvokeIR(
                toolID: ir.toolID,
                arguments: ir.arguments.map(normalized),
                resultBinding: ir.resultBinding.map(normalizeIdentifier),
                comment: nil,
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .bind(let ir):
            return .bind(BindIR(
                name: normalizeIdentifier(ir.name),
                expression: normalized(ir.expression),
                isRebind: ir.isRebind,
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .branch(let ir):
            return .branch(BranchIR(
                condition: normalized(ir.condition),
                thenBlock: normalized(ir.thenBlock),
                unknownBlock: ir.unknownBlock.map(normalized),
                elseBlock: ir.elseBlock.map(normalized),
                unknownPolicy: ir.unknownPolicy,
                authoredForm: ir.authoredForm,
                deonticGuard: ir.deonticGuard.map(normalized),
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .iterate(let ir):
            return .iterate(IterateIR(
                mode: normalized(ir.mode),
                body: normalized(ir.body),
                source: ir.source.map(normalized),
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .assert(let ir):
            return .assert(AssertIR(
                condition: normalized(ir.condition),
                message: nil,
                otherwiseAction: ir.otherwiseAction.map(normalized),
                monitored: ir.monitored,
                cadence: ir.cadence,
                blocking: ir.blocking,
                normID: ir.normID,
                violationDisposition: ir.violationDisposition,
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .emit(let ir):
            return .emit(EmitIR(
                eventID: ir.eventID,
                payload: ir.payload.map(normalized),
                strict: ir.strict,
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .wait(let ir):
            return .wait(WaitIR(
                condition: normalized(ir.condition),
                timeout: ir.timeout,
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .commit(let ir):
            return .commit(CommitIR(label: ir.label, sourceRange: .unknown, stableStepPath: nil))
        case .recover(let ir):
            return .recover(RecoverIR(
                pattern: normalized(ir.pattern),
                handler: normalized(ir.handler),
                attachedTo: normalized(ir.attachedTo),
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .simultaneously(let ir):
            return .simultaneously(SimultaneouslyIR(
                branches: ir.branches.map(normalized),
                detached: ir.detached,
                sourceRange: .unknown,
                stableStepPath: nil
            ))
        case .aiJudgment(let ir):
            return .aiJudgment(AIJudgmentIR(
                text: normalizeAIText(ir.text),
                scopedTools: ir.scopedTools,
                snapshotKeys: ir.snapshotKeys,
                sourceRange: .unknown,
                guidance: ir.guidance.map(normalizeAIText),
                stableStepPath: nil,
                outputKind: ""
            ))
        case .aiAutonomy(let ir):
            return .aiAutonomy(AIAutonomyIR(
                text: normalizeAIText(ir.text),
                scopedTools: ir.scopedTools,
                snapshotKeys: ir.snapshotKeys,
                autonomy: normalized(ir.autonomy),
                sourceRange: .unknown,
                guidance: ir.guidance.map(normalizeAIText),
                stableStepPath: nil,
                outputKind: ""
            ))
        case .complete(let ir):
            return .complete(CompleteIR(reason: ir.reason, sourceRange: .unknown, stableStepPath: nil))
        }
    }

    static func normalized(_ a: InvokeIR) -> InvokeIR {
        InvokeIR(
            toolID: a.toolID,
            arguments: a.arguments.map(normalized),
            resultBinding: a.resultBinding.map(normalizeIdentifier),
            comment: nil,
            sourceRange: .unknown,
            stableStepPath: nil
        )
    }

    static func normalized(_ a: InvokeArg) -> InvokeArg {
        InvokeArg(normalizeIdentifier(a.key), normalized(a.value))
    }

    static func normalized(_ a: EmitField) -> EmitField {
        EmitField(normalizeIdentifier(a.key), normalized(a.value))
    }

    static func normalized(_ a: BranchCondition) -> BranchCondition {
        switch a {
        case .predicate(let expression):
            return .predicate(normalized(expression))
        case .match(let expression, let cases):
            return .match(normalized(expression), cases.map(normalized))
        }
    }

    static func normalized(_ a: BranchCase) -> BranchCase {
        BranchCase(pattern: normalized(a.pattern), block: normalized(a.block))
    }

    static func normalized(_ a: IRPattern) -> IRPattern {
        switch a {
        case .literal(let literal):
            return .literal(normalized(literal))
        case .enumValue(let value, let kind):
            return .enumValue(value, kind: normalizeIdentifier(kind))
        case .wildcard:
            return .wildcard
        }
    }

    static func normalized(_ a: IterateMode) -> IterateMode {
        switch a {
        case .overCollection(let parameter, let kind, let collection):
            return .overCollection(
                parameter: normalizeIdentifier(parameter),
                kind: KindRef(normalizeIdentifier(kind.name)),
                collection: normalized(collection)
            )
        case .whileCondition(let condition):
            return .whileCondition(normalized(condition))
        case .untilCondition(let condition):
            return .untilCondition(normalized(condition))
        }
    }

    static func normalized(_ a: IRIterationRefinement) -> IRIterationRefinement {
        IRIterationRefinement(
            filters: a.filters.map(normalized),
            sort: a.sort.map(normalized),
            take: a.take,
            takeFromEnd: a.takeFromEnd
        )
    }

    static func normalized(_ a: IRSortSpec) -> IRSortSpec {
        IRSortSpec(path: normalizeIdentifier(a.path), ascending: a.ascending)
    }

    static func normalized(_ a: WaitConditionIR) -> WaitConditionIR {
        switch a {
        case .duration(let duration):
            return .duration(duration)
        case .signal(let name):
            return .signal(name)
        case .approval(let of, let by):
            return .approval(of: normalized(of), by: normalizeIdentifier(by))
        case .event(let id, let matching):
            return .event(id, matching: matching.map(normalized))
        case .choice(let prompt, let options):
            return .choice(prompt: prompt, options: options)
        }
    }

    static func normalized(_ a: ErrorPattern) -> ErrorPattern {
        switch a {
        case .anyError:
            return .anyError
        case .named(let name):
            return .named(name)
        case .typed(let kind):
            return .typed(KindRef(normalizeIdentifier(kind.name)))
        case .predicate(let expression):
            return .predicate(normalized(expression))
        }
    }

    static func normalized(_ a: AutonomyConfigIR) -> AutonomyConfigIR {
        AutonomyConfigIR(
            until: a.until.map(normalized),
            unless: a.unless.map(normalized),
            replanAfterFailures: a.replanAfterFailures,
            maxSteps: a.maxSteps
        )
    }

    // MARK: - Expressions

    static func normalized(_ a: IRExpression) -> IRExpression {
        switch a {
        case .literal(let literal):
            return .literal(normalized(literal))
        case .constantRef(let name):
            return .constantRef(name: normalizeIdentifier(name))
        case .identifierRef(let name):
            return .identifierRef(name: normalizeIdentifier(name))
        case .instanceRef(let name):
            return .instanceRef(name: normalizeIdentifier(name))
        case .propertyAccess(let base, let propertyName):
            return .propertyAccess(normalized(base), propertyName: normalizeIdentifier(propertyName))
        case .relationTraversal(let base, let relationName, let target):
            return .relationTraversal(
                normalized(base),
                relationName: normalizeIdentifier(relationName),
                target: target.map(normalized)
            )
        case .comparison(let lhs, let op, let rhs):
            return .comparison(normalized(lhs), op, normalized(rhs))
        case .logical(let op, let operands):
            return .logical(op, operands.map(normalized))
        case .envVar(let name):
            return .envVar(name: name)
        case .nowExpression:
            return .nowExpression
        case .invocation(let invoke):
            return .invocation(normalized(invoke))
        case .interpolatedString(let segments):
            return .interpolatedString(segments.map(normalized))
        case .recordList(let fields, let rows):
            return .recordList(
                fields: fields.map(normalizeIdentifier),
                rows: rows.map { $0.map(normalized) }
            )
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return .tableLookup(
                table: normalizeIdentifier(table),
                keyColumn: normalizeIdentifier(keyColumn),
                key: normalized(key),
                valueColumn: normalizeIdentifier(valueColumn)
            )
        case .definitionPredicate(let functionName, let subject):
            return .definitionPredicate(
                functionName: normalizeIdentifier(functionName),
                subject: normalized(subject)
            )
        case .quantified(let quantifier):
            return .quantified(normalized(quantifier))
        case .description(let description):
            return .description(normalized(description))
        case .aggregate(let kind, let description):
            return .aggregate(kind, normalized(description))
        case .superlative(let superlative):
            return .superlative(normalized(superlative))
        case .eventPattern(let pattern):
            return .eventPattern(normalized(pattern))
        case .traceTemporal(let temporal):
            return .traceTemporal(normalized(temporal))
        case .traceStatistical(let statistical):
            return .traceStatistical(normalized(statistical))
        }
    }

    static func normalized(_ a: IRInterpolationSegment) -> IRInterpolationSegment {
        switch a {
        case .literal(let text):
            return .literal(text)
        case .expression(let expression):
            return .expression(normalized(expression))
        case .conditional(let condition, let then, let otherwise):
            return .conditional(
                condition: normalized(condition),
                then: then.map(normalized),
                otherwise: otherwise.map(normalized)
            )
        case .forEach(let variable, let collection, let body):
            return .forEach(
                variable: normalizeIdentifier(variable),
                collection: normalized(collection),
                body: body.map(normalized)
            )
        case .formatted(let expression, let formatter):
            return .formatted(normalized(expression), formatter: normalizeIdentifier(formatter))
        case .shellEscapedExpression(let expression):
            return .shellEscapedExpression(normalized(expression))
        }
    }

    static func normalized(_ a: QuantifierIR) -> QuantifierIR {
        QuantifierIR(
            kind: a.kind,
            description: normalized(a.description),
            body: a.body.map(normalized)
        )
    }

    static func normalized(_ a: DescriptionIR) -> DescriptionIR {
        DescriptionIR(
            collection: normalized(a.collection),
            elementVar: normalizeIdentifier(a.elementVar),
            filters: a.filters.map(normalized),
            sort: a.sort.map(normalized),
            take: a.take,
            takeFromEnd: a.takeFromEnd
        )
    }

    static func normalized(_ a: SuperlativeIR) -> SuperlativeIR {
        SuperlativeIR(
            description: normalized(a.description),
            sortPath: normalizeIdentifier(a.sortPath),
            ascending: a.ascending
        )
    }

    static func normalized(_ a: IRLiteral) -> IRLiteral {
        switch a {
        case .string(let value):
            return .string(normalizeStringLiteral(value))
        case .number(let value):
            return .number(value)
        case .boolean(let value):
            return .boolean(value)
        case .money(let amount, let currency):
            return .money(amount, currency: currency)
        case .duration(let duration):
            return .duration(duration)
        case .calendarAmount(let amount):
            return .calendarAmount(amount)
        case .date(let date):
            return .date(date)
        case .dateTime(let dateTime):
            return .dateTime(dateTime)
        case .enumValue(let value, let kind):
            return .enumValue(value, kind: kind)
        }
    }

    // MARK: - Trace queries

    static func normalized(_ a: EventPatternIR) -> EventPatternIR {
        EventPatternIR(
            subject: normalized(a.subject),
            outcome: a.outcome,
            payloadPredicate: a.payloadPredicate.map(normalized),
            negated: false
        )
    }

    static func normalized(_ a: EventPatternIR.Subject) -> EventPatternIR.Subject {
        switch a {
        case .step(let name):
            return .step(normalizeIdentifier(name))
        case .named(let name):
            return .named(normalizeIdentifier(name))
        }
    }

    static func normalized(_ a: TraceTemporalIR) -> TraceTemporalIR {
        TraceTemporalIR(
            scope: a.scope,
            kind: normalized(a.kind),
            subjectKeyExpr: a.subjectKeyExpr.map(normalized)
        )
    }

    static func normalized(_ a: TraceTemporalKind) -> TraceTemporalKind {
        switch a {
        case .ever(let pattern):
            return .ever(normalized(pattern))
        case .withinWindow(let pattern, let duration):
            return .withinWindow(normalized(pattern), duration: duration)
        case .countInWindow(let pattern, let comparator, let duration):
            return .countInWindow(normalized(pattern), comparator: comparator, duration: duration)
        case .inARow(let pattern, let count):
            return .inARow(normalized(pattern), count: count)
        case .sinceLast(let anchor, let holds, let holdsPattern, let holdsUsesStateHistory):
            return .sinceLast(
                anchor: normalized(anchor),
                holds: normalized(holds),
                holdsPattern: holdsPattern.map(normalized),
                holdsUsesStateHistory: holdsUsesStateHistory
            )
        case .boundedFutureMonitor(let condition, let horizon, let mode):
            return .boundedFutureMonitor(
                condition: normalized(condition),
                horizon: horizon,
                mode: mode
            )
        }
    }

    static func normalized(_ a: TraceStatisticalPatternIR) -> TraceStatisticalPatternIR {
        TraceStatisticalPatternIR(
            subject: normalized(a.subject),
            payloadPredicate: a.payloadPredicate.map(normalized)
        )
    }

    static func normalized(_ a: TraceStatisticalIR) -> TraceStatisticalIR {
        TraceStatisticalIR(
            scope: a.scope,
            pattern: normalized(a.pattern),
            outcome: a.outcome,
            bound: a.bound,
            denominator: a.denominator,
            window: a.window,
            monitorCadence: a.monitorCadence,
            blocking: a.blocking,
            confidencePercent: nil,
            subjectKeyExpr: a.subjectKeyExpr.map(normalized)
        )
    }

    // MARK: - Deontic norms

    static func normalized(_ a: NormIR) -> NormIR {
        NormIR(
            id: a.id,
            kind: a.kind,
            scope: a.scope,
            actionPattern: a.actionPattern.map(normalized),
            condition: a.condition.map(normalized),
            blocking: a.blocking,
            sourceRange: .unknown,
            originalText: a.originalText
        )
    }

    static func normalized(_ a: ActionPatternIR) -> ActionPatternIR {
        ActionPatternIR(toolID: a.toolID, argumentConstraints: a.argumentConstraints.map(normalized))
    }

    static func normalized(_ a: ActionArgumentConstraint) -> ActionArgumentConstraint {
        ActionArgumentConstraint(path: normalizeIdentifier(a.path), op: a.op, value: normalized(a.value))
    }

    static func normalized(_ a: DeonticGuardIR) -> DeonticGuardIR {
        DeonticGuardIR(
            normID: a.normID,
            disposition: a.disposition,
            blocking: a.blocking,
            actionPattern: normalized(a.actionPattern)
        )
    }
}
