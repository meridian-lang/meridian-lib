import Foundation
import MeridianRuntime

public enum IREquality {
    public static func structurallyEqual(_ a: [IRWorkflow], _ b: [IRWorkflow]) -> Bool {
        equalArrays(a, b, by: structurallyEqual)
    }

    public static func structurallyEqual(_ a: IRWorkflow, _ b: IRWorkflow) -> Bool {
        identifierEqual(a.name, b.name)
            && identifierEqual(a.structName, b.structName)
            && equalArrays(a.parameters, b.parameters, by: structurallyEqual)
            && structurallyEqual(a.body, b.body)
            && a.mode == b.mode
            && a.allowsDiscretion == b.allowsDiscretion
    }

    public static func structurallyEqual(_ a: IRBlock, _ b: IRBlock) -> Bool {
        equalArrays(a.statements, b.statements, by: structurallyEqual)
    }

    public static func structurallyEqual(_ a: IRParameter, _ b: IRParameter) -> Bool {
        identifierEqual(a.name, b.name) && identifierEqual(a.kind.name, b.kind.name)
    }

    public static func structurallyEqual(_ a: LoweredDefinition, _ b: LoweredDefinition) -> Bool {
        identifierEqual(a.functionName, b.functionName)
            && identifierEqual(a.subjectVar, b.subjectVar)
            && structurallyEqual(a.body, b.body)
    }

    public static func structurallyEqual(_ a: IRPrimitive, _ b: IRPrimitive) -> Bool {
        switch a {
        case .invoke(let lhs):
            guard case .invoke(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .bind(let lhs):
            guard case .bind(let rhs) = b else { return false }
            return identifierEqual(lhs.name, rhs.name)
                && lhs.isRebind == rhs.isRebind
                && structurallyEqual(lhs.expression, rhs.expression)
        case .branch(let lhs):
            guard case .branch(let rhs) = b else { return false }
            return structurallyEqual(lhs.condition, rhs.condition)
                && structurallyEqual(lhs.thenBlock, rhs.thenBlock)
                && structurallyEqual(lhs.unknownBlock, rhs.unknownBlock)
                && structurallyEqual(lhs.elseBlock, rhs.elseBlock)
        case .iterate(let lhs):
            guard case .iterate(let rhs) = b else { return false }
            return structurallyEqual(lhs.mode, rhs.mode)
                && structurallyEqual(lhs.body, rhs.body)
                && structurallyEqual(lhs.source, rhs.source)
        case .assert(let lhs):
            guard case .assert(let rhs) = b else { return false }
            return structurallyEqual(lhs.condition, rhs.condition)
                && structurallyEqual(lhs.otherwiseAction, rhs.otherwiseAction)
                && lhs.monitored == rhs.monitored
                && lhs.cadence == rhs.cadence
                && lhs.blocking == rhs.blocking
        case .emit(let lhs):
            guard case .emit(let rhs) = b else { return false }
            return lhs.eventID == rhs.eventID
                && lhs.strict == rhs.strict
                && equalArrays(lhs.payload, rhs.payload, by: structurallyEqual)
        case .wait(let lhs):
            guard case .wait(let rhs) = b else { return false }
            return structurallyEqual(lhs.condition, rhs.condition)
                && lhs.timeout == rhs.timeout
        case .commit(let lhs):
            guard case .commit(let rhs) = b else { return false }
            return lhs.label == rhs.label
        case .recover(let lhs):
            guard case .recover(let rhs) = b else { return false }
            return structurallyEqual(lhs.pattern, rhs.pattern)
                && structurallyEqual(lhs.handler, rhs.handler)
                && structurallyEqual(lhs.attachedTo, rhs.attachedTo)
        case .simultaneously(let lhs):
            guard case .simultaneously(let rhs) = b else { return false }
            return lhs.detached == rhs.detached
                && equalArrays(lhs.branches, rhs.branches, by: structurallyEqual)
        case .aiJudgment(let lhs):
            guard case .aiJudgment(let rhs) = b else { return false }
            return aiTextEqual(lhs.text, rhs.text)
                && lhs.scopedTools == rhs.scopedTools
                && lhs.snapshotKeys == rhs.snapshotKeys
                && aiOptionalTextEqual(lhs.guidance, rhs.guidance)
        case .aiAutonomy(let lhs):
            guard case .aiAutonomy(let rhs) = b else { return false }
            return aiTextEqual(lhs.text, rhs.text)
                && lhs.scopedTools == rhs.scopedTools
                && lhs.snapshotKeys == rhs.snapshotKeys
                && structurallyEqual(lhs.autonomy, rhs.autonomy)
                && aiOptionalTextEqual(lhs.guidance, rhs.guidance)
        case .complete(let lhs):
            guard case .complete(let rhs) = b else { return false }
            return lhs.reason == rhs.reason
        }
    }

    public static func structurallyEqual(_ a: IRExpression, _ b: IRExpression) -> Bool {
        switch a {
        case .literal(let lhs):
            guard case .literal(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .constantRef(let lhs):
            guard case .constantRef(let rhs) = b else { return false }
            return identifierEqual(lhs, rhs)
        case .identifierRef(let lhs):
            guard case .identifierRef(let rhs) = b else { return false }
            return identifierEqual(lhs, rhs)
        case .instanceRef(let lhs):
            guard case .instanceRef(let rhs) = b else { return false }
            return identifierEqual(lhs, rhs)
        case .propertyAccess(let lhsBase, let lhsProp):
            guard case .propertyAccess(let rhsBase, let rhsProp) = b else { return false }
            return identifierEqual(lhsProp, rhsProp) && structurallyEqual(lhsBase, rhsBase)
        case .relationTraversal(let lhsBase, let lhsRel, let lhsTarget):
            guard case .relationTraversal(let rhsBase, let rhsRel, let rhsTarget) = b else { return false }
            return identifierEqual(lhsRel, rhsRel)
                && structurallyEqual(lhsBase, rhsBase)
                && structurallyEqual(lhsTarget, rhsTarget)
        case .comparison(let lhsLeft, let lhsOp, let lhsRight):
            guard case .comparison(let rhsLeft, let rhsOp, let rhsRight) = b else { return false }
            return structurallyEqual(lhsOp, rhsOp)
                && structurallyEqual(lhsLeft, rhsLeft)
                && structurallyEqual(lhsRight, rhsRight)
        case .logical(let lhsOp, let lhsOperands):
            guard case .logical(let rhsOp, let rhsOperands) = b else { return false }
            return structurallyEqual(lhsOp, rhsOp)
                && equalArrays(lhsOperands, rhsOperands, by: structurallyEqual)
        case .envVar(let lhs):
            guard case .envVar(let rhs) = b else { return false }
            return lhs == rhs
        case .nowExpression:
            guard case .nowExpression = b else { return false }
            return true
        case .invocation(let lhs):
            guard case .invocation(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .interpolatedString(let lhs):
            guard case .interpolatedString(let rhs) = b else { return false }
            return equalArrays(lhs, rhs, by: structurallyEqual)
        case .recordList(let lhsFields, let lhsRows):
            guard case .recordList(let rhsFields, let rhsRows) = b else { return false }
            return equalArrays(lhsFields, rhsFields, by: identifierEqual)
                && equalArrays(lhsRows, rhsRows) { equalArrays($0, $1, by: structurallyEqual) }
        case .tableLookup(let lhsTable, let lhsKeyColumn, let lhsKey, let lhsValueColumn):
            guard case .tableLookup(let rhsTable, let rhsKeyColumn, let rhsKey, let rhsValueColumn) = b else {
                return false
            }
            return identifierEqual(lhsTable, rhsTable)
                && identifierEqual(lhsKeyColumn, rhsKeyColumn)
                && identifierEqual(lhsValueColumn, rhsValueColumn)
                && structurallyEqual(lhsKey, rhsKey)
        case .definitionPredicate(let lhsFunction, let lhsSubject):
            guard case .definitionPredicate(let rhsFunction, let rhsSubject) = b else { return false }
            return identifierEqual(lhsFunction, rhsFunction) && structurallyEqual(lhsSubject, rhsSubject)
        case .quantified(let lhs):
            guard case .quantified(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .description(let lhs):
            guard case .description(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .aggregate(let lhsKind, let lhsDescription):
            guard case .aggregate(let rhsKind, let rhsDescription) = b else { return false }
            return lhsKind == rhsKind && structurallyEqual(lhsDescription, rhsDescription)
        case .superlative(let lhs):
            guard case .superlative(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .eventPattern(let lhs):
            guard case .eventPattern(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .traceTemporal(let lhs):
            guard case .traceTemporal(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        case .traceStatistical(let lhs):
            guard case .traceStatistical(let rhs) = b else { return false }
            return structurallyEqual(lhs, rhs)
        }
    }

    public static func structurallyEqual(_ a: InvokeIR, _ b: InvokeIR) -> Bool {
        a.toolID == b.toolID
            && optionalIdentifierEqual(a.resultBinding, b.resultBinding)
            && equalArrays(a.arguments, b.arguments, by: structurallyEqual)
    }

    public static func structurallyEqual(_ a: InvokeArg, _ b: InvokeArg) -> Bool {
        identifierEqual(a.key, b.key) && structurallyEqual(a.value, b.value)
    }

    public static func structurallyEqual(_ a: EmitField, _ b: EmitField) -> Bool {
        identifierEqual(a.key, b.key) && structurallyEqual(a.value, b.value)
    }

    public static func structurallyEqual(_ a: BranchCondition, _ b: BranchCondition) -> Bool {
        switch (a, b) {
        case (.predicate(let lhs), .predicate(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.match(let lhsExpr, let lhsCases), .match(let rhsExpr, let rhsCases)):
            return structurallyEqual(lhsExpr, rhsExpr)
                && equalArrays(lhsCases, rhsCases, by: structurallyEqual)
        case (.predicate, _), (.match, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: EventPatternIR, _ b: EventPatternIR) -> Bool {
        structurallyEqual(a.subject, b.subject)
            && a.outcome == b.outcome
            && structurallyEqual(a.payloadPredicate, b.payloadPredicate)
    }

    public static func structurallyEqual(_ a: EventPatternIR.Subject, _ b: EventPatternIR.Subject) -> Bool {
        switch (a, b) {
        case (.step(let lhs), .step(let rhs)),
             (.named(let lhs), .named(let rhs)):
            return identifierEqual(lhs, rhs)
        case (.step, _), (.named, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: TraceTemporalIR, _ b: TraceTemporalIR) -> Bool {
        a.scope == b.scope
            && structurallyEqual(a.kind, b.kind)
            && structurallyEqual(a.subjectKeyExpr, b.subjectKeyExpr)
    }

    public static func structurallyEqual(_ a: TraceStatisticalPatternIR, _ b: TraceStatisticalPatternIR) -> Bool {
        structurallyEqual(a.subject, b.subject)
            && structurallyEqual(a.payloadPredicate, b.payloadPredicate)
    }

    public static func structurallyEqual(_ a: TraceStatisticalIR, _ b: TraceStatisticalIR) -> Bool {
        a.scope == b.scope
            && structurallyEqual(a.pattern, b.pattern)
            && structurallyEqual(a.outcome, b.outcome)
            && structurallyEqual(a.bound, b.bound)
            && a.denominator == b.denominator
            && a.window == b.window
            && a.monitorCadence == b.monitorCadence
            && a.blocking == b.blocking
            && structurallyEqual(a.subjectKeyExpr, b.subjectKeyExpr)
    }

    public static func structurallyEqual(_ a: TraceTemporalKind, _ b: TraceTemporalKind) -> Bool {
        switch (a, b) {
        case (.ever(let lhs), .ever(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.withinWindow(let lhsPattern, let lhsDuration),
              .withinWindow(let rhsPattern, let rhsDuration)):
            return structurallyEqual(lhsPattern, rhsPattern) && lhsDuration == rhsDuration
        case (.countInWindow(let lhsPattern, let lhsComparator, let lhsDuration),
              .countInWindow(let rhsPattern, let rhsComparator, let rhsDuration)):
            return structurallyEqual(lhsPattern, rhsPattern)
                && structurallyEqual(lhsComparator, rhsComparator)
                && lhsDuration == rhsDuration
        case (.inARow(let lhsPattern, let lhsCount),
              .inARow(let rhsPattern, let rhsCount)):
            return structurallyEqual(lhsPattern, rhsPattern) && lhsCount == rhsCount
        case (.sinceLast(let lhsAnchor, let lhsHolds, let lhsHoldsPattern),
              .sinceLast(let rhsAnchor, let rhsHolds, let rhsHoldsPattern)):
            return structurallyEqual(lhsAnchor, rhsAnchor)
                && structurallyEqual(lhsHolds, rhsHolds)
                && structurallyEqual(lhsHoldsPattern, rhsHoldsPattern)
        case (.ever, _), (.withinWindow, _), (.countInWindow, _), (.inARow, _), (.sinceLast, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: TraceStatisticalOutcomeIR, _ b: TraceStatisticalOutcomeIR) -> Bool {
        switch (a, b) {
        case (.succeeds, .succeeds), (.fails, .fails):
            return true
        default:
            return false
        }
    }

    public static func structurallyEqual(_ a: TraceStatisticalBoundIR, _ b: TraceStatisticalBoundIR) -> Bool {
        switch (a, b) {
        case (.atLeast(let lhs), .atLeast(let rhs)),
             (.atMost(let lhs), .atMost(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }

    public static func structurallyEqual(_ a: TraceCountComparatorIR, _ b: TraceCountComparatorIR) -> Bool {
        switch (a, b) {
        case (.atLeast(let lhs), .atLeast(let rhs)),
             (.atMost(let lhs), .atMost(let rhs)),
             (.exactly(let lhs), .exactly(let rhs)):
            return lhs == rhs
        case (.atLeast, _), (.atMost, _), (.exactly, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: BranchCase, _ b: BranchCase) -> Bool {
        structurallyEqual(a.pattern, b.pattern) && structurallyEqual(a.block, b.block)
    }

    public static func structurallyEqual(_ a: IRPattern, _ b: IRPattern) -> Bool {
        switch (a, b) {
        case (.literal(let lhs), .literal(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.enumValue(let lhsValue, let lhsKind), .enumValue(let rhsValue, let rhsKind)):
            return lhsValue == rhsValue && identifierEqual(lhsKind, rhsKind)
        case (.wildcard, .wildcard):
            return true
        case (.literal, _), (.enumValue, _), (.wildcard, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: IterateMode, _ b: IterateMode) -> Bool {
        switch (a, b) {
        case (.overCollection(let lhsParam, let lhsKind, let lhsCollection),
              .overCollection(let rhsParam, let rhsKind, let rhsCollection)):
            return identifierEqual(lhsParam, rhsParam)
                && identifierEqual(lhsKind.name, rhsKind.name)
                && structurallyEqual(lhsCollection, rhsCollection)
        case (.whileCondition(let lhs), .whileCondition(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.untilCondition(let lhs), .untilCondition(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.overCollection, _), (.whileCondition, _), (.untilCondition, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: IRIterationRefinement?, _ b: IRIterationRefinement?) -> Bool {
        switch (a, b) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.none, .some), (.some, .none):
            return false
        }
    }

    public static func structurallyEqual(_ a: IRIterationRefinement, _ b: IRIterationRefinement) -> Bool {
        equalArrays(a.filters, b.filters, by: structurallyEqual)
            && equalSort(a.sort, b.sort)
            && a.take == b.take
    }

    public static func structurallyEqual(_ a: WaitConditionIR, _ b: WaitConditionIR) -> Bool {
        switch (a, b) {
        case (.duration(let lhs), .duration(let rhs)):
            return lhs == rhs
        case (.signal(let lhs), .signal(let rhs)):
            return lhs == rhs
        case (.approval(let lhsSubject, let lhsRole), .approval(let rhsSubject, let rhsRole)):
            return identifierEqual(lhsRole, rhsRole) && structurallyEqual(lhsSubject, rhsSubject)
        case (.event(let lhsID, let lhsMatch), .event(let rhsID, let rhsMatch)):
            return lhsID == rhsID && structurallyEqual(lhsMatch, rhsMatch)
        case (.choice(let lhsPrompt, let lhsOptions), .choice(let rhsPrompt, let rhsOptions)):
            return lhsPrompt == rhsPrompt && lhsOptions == rhsOptions
        case (.duration, _), (.signal, _), (.approval, _), (.event, _), (.choice, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: ErrorPattern, _ b: ErrorPattern) -> Bool {
        switch (a, b) {
        case (.anyError, .anyError):
            return true
        case (.named(let lhs), .named(let rhs)):
            return lhs == rhs
        case (.typed(let lhs), .typed(let rhs)):
            return identifierEqual(lhs.name, rhs.name)
        case (.predicate(let lhs), .predicate(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.anyError, _), (.named, _), (.typed, _), (.predicate, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: AutonomyConfigIR, _ b: AutonomyConfigIR) -> Bool {
        structurallyEqual(a.until, b.until)
            && structurallyEqual(a.unless, b.unless)
            && a.replanAfterFailures == b.replanAfterFailures
            && a.maxSteps == b.maxSteps
    }

    public static func structurallyEqual(_ a: IRInterpolationSegment, _ b: IRInterpolationSegment) -> Bool {
        switch (a, b) {
        case (.literal(let lhs), .literal(let rhs)):
            return lhs == rhs
        case (.expression(let lhs), .expression(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.conditional(let lhsCondition, let lhsThen, let lhsOtherwise),
              .conditional(let rhsCondition, let rhsThen, let rhsOtherwise)):
            return structurallyEqual(lhsCondition, rhsCondition)
                && equalArrays(lhsThen, rhsThen, by: structurallyEqual)
                && equalArrays(lhsOtherwise, rhsOtherwise, by: structurallyEqual)
        case (.forEach(let lhsVariable, let lhsCollection, let lhsBody),
              .forEach(let rhsVariable, let rhsCollection, let rhsBody)):
            return identifierEqual(lhsVariable, rhsVariable)
                && structurallyEqual(lhsCollection, rhsCollection)
                && equalArrays(lhsBody, rhsBody, by: structurallyEqual)
        case (.formatted(let lhsExpression, let lhsFormatter), .formatted(let rhsExpression, let rhsFormatter)):
            return identifierEqual(lhsFormatter, rhsFormatter) && structurallyEqual(lhsExpression, rhsExpression)
        case (.shellEscapedExpression(let lhs), .shellEscapedExpression(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.literal, _), (.expression, _), (.conditional, _), (.forEach, _),
             (.formatted, _), (.shellEscapedExpression, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: QuantifierIR, _ b: QuantifierIR) -> Bool {
        structurallyEqual(a.kind, b.kind)
            && structurallyEqual(a.description, b.description)
            && structurallyEqual(a.body, b.body)
    }

    public static func structurallyEqual(_ a: QuantifierKind, _ b: QuantifierKind) -> Bool {
        switch (a, b) {
        case (.all, .all), (.any, .any), (.none, .none):
            return true
        case (.atLeast(let lhs), .atLeast(let rhs)),
             (.atMost(let lhs), .atMost(let rhs)),
             (.exactly(let lhs), .exactly(let rhs)):
            return lhs == rhs
        case (.all, _), (.any, _), (.none, _), (.atLeast, _), (.atMost, _), (.exactly, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: DescriptionIR, _ b: DescriptionIR) -> Bool {
        structurallyEqual(a.collection, b.collection)
            && identifierEqual(a.elementVar, b.elementVar)
            && equalArrays(a.filters, b.filters, by: structurallyEqual)
            && equalSort(a.sort, b.sort)
            && a.take == b.take
    }

    public static func structurallyEqual(_ a: SuperlativeIR, _ b: SuperlativeIR) -> Bool {
        structurallyEqual(a.description, b.description)
            && identifierEqual(a.sortPath, b.sortPath)
            && a.ascending == b.ascending
    }

    public static func structurallyEqual(_ a: IRLiteral, _ b: IRLiteral) -> Bool {
        switch (a, b) {
        case (.string(let lhs), .string(let rhs)):
            return stringLiteralEqual(lhs, rhs)
        case (.number(let lhs), .number(let rhs)):
            return lhs == rhs
        case (.boolean(let lhs), .boolean(let rhs)):
            return lhs == rhs
        case (.money(let lhsAmount, let lhsCurrency), .money(let rhsAmount, let rhsCurrency)):
            return lhsAmount == rhsAmount && lhsCurrency == rhsCurrency
        case (.duration(let lhs), .duration(let rhs)):
            return lhs == rhs
        case (.date(let lhs), .date(let rhs)):
            return lhs == rhs
        case (.dateTime(let lhs), .dateTime(let rhs)):
            return lhs == rhs
        case (.enumValue(let lhsValue, let lhsKind), .enumValue(let rhsValue, let rhsKind)):
            return lhsValue == rhsValue && lhsKind == rhsKind
        case (.string, _), (.number, _), (.boolean, _), (.money, _),
             (.duration, _), (.date, _), (.dateTime, _), (.enumValue, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: ComparisonOp, _ b: ComparisonOp) -> Bool {
        switch a {
        case .equal:
            guard case .equal = b else { return false }
        case .notEqual:
            guard case .notEqual = b else { return false }
        case .lessThan:
            guard case .lessThan = b else { return false }
        case .lessOrEqual:
            guard case .lessOrEqual = b else { return false }
        case .greaterThan:
            guard case .greaterThan = b else { return false }
        case .greaterOrEqual:
            guard case .greaterOrEqual = b else { return false }
        case .oneOf:
            guard case .oneOf = b else { return false }
        case .contains:
            guard case .contains = b else { return false }
        case .startsWith:
            guard case .startsWith = b else { return false }
        case .endsWith:
            guard case .endsWith = b else { return false }
        case .withinDuration:
            guard case .withinDuration = b else { return false }
        case .withinPast:
            guard case .withinPast = b else { return false }
        case .withinFuture:
            guard case .withinFuture = b else { return false }
        case .matchesPattern:
            guard case .matchesPattern = b else { return false }
        case .isEmpty:
            guard case .isEmpty = b else { return false }
        case .isNotEmpty:
            guard case .isNotEmpty = b else { return false }
        case .identifies:
            guard case .identifies = b else { return false }
        }
        return true
    }

    public static func structurallyEqual(_ a: LogicalOp, _ b: LogicalOp) -> Bool {
        switch (a, b) {
        case (.and, .and), (.or, .or), (.not, .not):
            return true
        case (.and, _), (.or, _), (.not, _):
            return false
        }
    }

    public static func structurallyEqual(_ a: IRExpression?, _ b: IRExpression?) -> Bool {
        switch (a, b) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.none, .some), (.some, .none):
            return false
        }
    }

    public static func structurallyEqual(_ a: IRBlock?, _ b: IRBlock?) -> Bool {
        switch (a, b) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return structurallyEqual(lhs, rhs)
        case (.none, .some), (.some, .none):
            return false
        }
    }

    private static func equalSort(_ a: (path: String, ascending: Bool)?, _ b: (path: String, ascending: Bool)?) -> Bool {
        switch (a, b) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return identifierEqual(lhs.path, rhs.path) && lhs.ascending == rhs.ascending
        case (.none, .some), (.some, .none):
            return false
        }
    }

    private static func equalArrays<T, U>(_ a: [T], _ b: [U], by compare: (T, U) -> Bool) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy(compare)
    }

    private static func stringLiteralEqual(_ a: String, _ b: String) -> Bool {
        normalizeStringLiteral(a) == normalizeStringLiteral(b)
    }

    private static func normalizeStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }

    private static func optionalIdentifierEqual(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return identifierEqual(lhs, rhs)
        case (.none, .some), (.some, .none):
            return false
        }
    }

    /// Public surface for diagnostics that must mirror structural identifier
    /// comparison (articles / case / non-alphanumerics stripped).
    public static func identifiersEqual(_ a: String, _ b: String) -> Bool {
        identifierEqual(a, b)
    }

    private static func identifierEqual(_ a: String, _ b: String) -> Bool {
        normalizeIdentifier(a) == normalizeIdentifier(b)
    }

    private static func normalizeIdentifier(_ value: String) -> String {
        // IR structural equality is lexicon-agnostic; use the default English
        // article set rather than re-listing surface vocabulary inline.
        let articles = EnglishLexicon.default.articles
        let words = value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !articles.contains($0) }
        return words.joined()
    }

    private static func aiOptionalTextEqual(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (.none, .none):
            return true
        case (.some(let lhs), .some(let rhs)):
            return aiTextEqual(lhs, rhs)
        case (.none, .some), (.some, .none):
            return false
        }
    }

    private static func aiTextEqual(_ a: String, _ b: String) -> Bool {
        normalizeAIText(a) == normalizeAIText(b)
    }

    private static func normalizeAIText(_ text: String) -> String {
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
}
