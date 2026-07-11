import Foundation
import MeridianRuntime

public enum IRValidationError: Error, Sendable {
    case diagnostics([Diagnostic])
}

public enum IRValidator {
    public static func validate(_ workflows: [IRWorkflow], sourceFile: String = "<ir>") throws {
        var validator = Validator(sourceFile: sourceFile, workflows: workflows)
        for workflow in workflows {
            validator.validate(workflow)
        }
        try validator.throwIfNeeded()
    }

    public static func validate(_ workflow: IRWorkflow, sourceFile: String = "<ir>") throws {
        try validate([workflow], sourceFile: workflow.sourceFile.isEmpty ? sourceFile : workflow.sourceFile)
    }

    public static func validate(_ expression: IRExpression, sourceFile: String = "<ir>") throws {
        var validator = Validator(sourceFile: sourceFile, workflows: [])
        validator.validate(expression, range: SourceRange(file: sourceFile, line: 0, column: 1), context: .standaloneExpression)
        try validator.throwIfNeeded()
    }
}

private struct Validator {
    enum Context: Equatable {
        case statement
        case valueExpression
        case standaloneExpression
    }

    let sourceFile: String
    let workflowsByStructName: [String: IRWorkflow]
    var diagnostics: [Diagnostic] = []

    init(sourceFile: String, workflows: [IRWorkflow]) {
        self.sourceFile = sourceFile
        var byStructName: [String: IRWorkflow] = [:]
        for workflow in workflows {
            byStructName[workflow.structName] = workflow
            if let explicit = workflow.explicitStructName {
                byStructName[explicit] = workflow
            }
        }
        self.workflowsByStructName = byStructName
    }

    mutating func validate(_ workflow: IRWorkflow) {
        validate(workflow.body, fallbackRange: workflow.sourceRange)
    }

    mutating func validate(_ block: IRBlock, fallbackRange: SourceRange) {
        for statement in block.statements {
            validate(statement, fallbackRange: block.sourceRange == .unknown ? fallbackRange : block.sourceRange)
        }
    }

    mutating func validate(_ primitive: IRPrimitive, fallbackRange: SourceRange) {
        switch primitive {
        case .invoke(let invoke):
            validate(invoke, range: concreteRange(invoke.sourceRange, fallback: fallbackRange), context: .statement)
        case .bind(let bind):
            validate(bind.expression, range: concreteRange(bind.sourceRange, fallback: fallbackRange), context: .valueExpression)
        case .branch(let branch):
            validate(branch)
        case .iterate(let iterate):
            validate(iterate)
        case .assert(let assertion):
            let range = concreteRange(assertion.sourceRange, fallback: fallbackRange)
            validate(assertion.condition, range: range, context: .valueExpression)
            if let otherwise = assertion.otherwiseAction {
                validate(otherwise, fallbackRange: range)
            }
        case .emit(let emit):
            let range = concreteRange(emit.sourceRange, fallback: fallbackRange)
            for field in emit.payload {
                if field.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    invalidIR("emit payload contains an empty field key", range: range)
                }
                validate(field.value, range: range, context: .valueExpression)
            }
        case .wait(let wait):
            validate(wait)
        case .commit:
            break
        case .recover(let recover):
            let range = concreteRange(recover.sourceRange, fallback: fallbackRange)
            validate(recover.pattern, range: range)
            validate(recover.attachedTo, fallbackRange: range)
            validate(recover.handler, fallbackRange: range)
        case .simultaneously(let simultaneously):
            let range = concreteRange(simultaneously.sourceRange, fallback: fallbackRange)
            for branch in simultaneously.branches {
                validate(branch, fallbackRange: range)
            }
        case .aiJudgment, .aiAutonomy, .complete:
            break
        }
    }

    mutating func validate(_ branch: BranchIR) {
        let range = concreteRange(branch.sourceRange, fallback: SourceRange(file: sourceFile, line: 0, column: 1))
        switch branch.condition {
        case .predicate(let expression):
            validate(expression, range: range, context: .valueExpression)
            validate(branch.thenBlock, fallbackRange: range)
            if let elseBlock = branch.elseBlock {
                validate(elseBlock, fallbackRange: range)
            }
        case .match(let expression, let cases):
            validate(expression, range: range, context: .valueExpression)
            validateMatch(cases: cases, otherwise: branch.thenBlock, range: range)
        }
    }

    mutating func validateMatch(cases: [BranchCase], otherwise: IRBlock, range: SourceRange) {
        if cases.isEmpty {
            matchSemantic(
                otherwise.statements.isEmpty
                    ? "match branch has no case arms"
                    : "match branch has an otherwise arm but no case arms",
                range: range)
        }

        var seenPatterns: [String: IRPattern] = [:]
        var defaultCount = otherwise.statements.isEmpty ? 0 : 1
        for branchCase in cases {
            let key = patternKey(branchCase.pattern)
            if seenPatterns[key] != nil {
                matchSemantic("match branch repeats pattern \(patternLabel(branchCase.pattern))", range: range)
            } else {
                seenPatterns[key] = branchCase.pattern
            }
            if case .wildcard = branchCase.pattern {
                defaultCount += 1
            }
            if branchCase.block.statements.isEmpty {
                matchSemantic("match branch \(patternLabel(branchCase.pattern)) has no statements", range: range)
            }
            validate(branchCase.block, fallbackRange: range)
        }

        if defaultCount > 1 {
            matchSemantic("match branch declares multiple wildcard/default arms", range: range)
        }
        if !otherwise.statements.isEmpty {
            validate(otherwise, fallbackRange: range)
        }
    }

    mutating func validate(_ iterate: IterateIR) {
        let range = concreteRange(iterate.sourceRange, fallback: SourceRange(file: sourceFile, line: 0, column: 1))
        switch iterate.mode {
        case .overCollection(let parameter, _, let collection):
            if parameter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("iteration has an empty parameter name", range: range)
            }
            validate(collection, range: range, context: .valueExpression)
        case .whileCondition(let condition), .untilCondition(let condition):
            validate(condition, range: range, context: .valueExpression)
        }
        if let refinement = iterate.source {
            for filter in refinement.filters {
                validate(filter, range: range, context: .valueExpression)
            }
            if let sort = refinement.sort,
               sort.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("iteration refinement has an empty sort path", range: range)
            }
        }
        validate(iterate.body, fallbackRange: range)
    }

    mutating func validate(_ wait: WaitIR) {
        let range = concreteRange(wait.sourceRange, fallback: SourceRange(file: sourceFile, line: 0, column: 1))
        switch wait.condition {
        case .duration:
            break
        case .signal(let signal):
            if signal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("wait signal is empty", range: range)
            }
        case .approval(let subject, let approver):
            validate(subject, range: range, context: .valueExpression)
            if approver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("wait approval approver is empty", range: range)
            }
        case .event(let event, let matching):
            if event.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("wait event is empty", range: range)
            }
            if let matching {
                validate(matching, range: range, context: .valueExpression)
            }
        case .choice(let prompt, let options):
            if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("choice prompt is empty", range: range)
            }
            if options.isEmpty || options.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                invalidIR("choice options must be non-empty strings", range: range)
            }
        }
    }

    mutating func validate(_ pattern: ErrorPattern, range: SourceRange) {
        switch pattern {
        case .anyError:
            break
        case .named(let name):
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("recover pattern name is empty", range: range)
            }
        case .typed(let kind):
            if kind.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("recover pattern kind is empty", range: range)
            }
        case .predicate(let predicate):
            validate(predicate, range: range, context: .valueExpression)
        }
    }

    mutating func validate(_ expression: IRExpression, range: SourceRange, context: Context) {
        switch expression {
        case .literal, .constantRef, .identifierRef, .instanceRef, .envVar, .nowExpression:
            break
        case .propertyAccess(let base, let propertyName):
            validate(base, range: range, context: context)
            if propertyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("property access has an empty property name", range: range)
            }
        case .relationTraversal(let base, let relationName, let target):
            validate(base, range: range, context: context)
            if relationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("relation traversal has an empty relation name", range: range)
            }
            if let target {
                validate(target, range: range, context: context)
            }
        case .comparison(let lhs, _, let rhs):
            validate(lhs, range: range, context: context)
            validate(rhs, range: range, context: context)
        case .logical(let op, let operands):
            if operands.isEmpty {
                invalidIR("logical \(logicalName(op)) expression has no operands", range: range)
            }
            if case .not = op, operands.count > 1 {
                invalidIR("logical not expression has more than one operand", range: range)
            }
            for operand in operands {
                validate(operand, range: range, context: context)
            }
        case .invocation(let invoke):
            validate(invoke, range: range, context: context)
            if context != .statement, invoke.toolID != "runtime.discretion.decide" {
                invalidIR("inline invocation \(invoke.toolID) cannot be emitted in expression position", range: range)
            }
        case .interpolatedString(let segments):
            validateInterpolation(segments, range: range)
        case .recordList(let fields, let rows):
            if fields.isEmpty {
                invalidIR("record list has no fields", range: range)
            }
            if fields.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                invalidIR("record list contains an empty field name", range: range)
            }
            for row in rows {
                if row.count != fields.count {
                    invalidIR("record list row has \(row.count) cells for \(fields.count) fields", range: range)
                }
                for cell in row {
                    validate(cell, range: range, context: .valueExpression)
                }
            }
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            if [table, keyColumn, valueColumn].contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                invalidIR("table lookup contains an empty table or column name", range: range)
            }
            validate(key, range: range, context: context)
        case .definitionPredicate(let functionName, let subject):
            if functionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("definition predicate has an empty function name", range: range)
            }
            validate(subject, range: range, context: context)
        case .quantified(let quantifier):
            validate(quantifier.description, range: range)
            if let body = quantifier.body {
                validate(body, range: range, context: context)
            }
        case .description(let description):
            validate(description, range: range)
        case .aggregate(_, let description):
            validate(description, range: range)
        case .superlative(let superlative):
            validate(superlative.description, range: range)
            if superlative.sortPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("superlative has an empty sort path", range: range)
            }
        }
    }

    mutating func validate(_ description: DescriptionIR, range: SourceRange) {
        validate(description.collection, range: range, context: .valueExpression)
        if description.elementVar.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            invalidIR("description has an empty element variable", range: range)
        }
        for filter in description.filters {
            validate(filter, range: range, context: .valueExpression)
        }
        if let sort = description.sort,
           sort.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            invalidIR("description has an empty sort path", range: range)
        }
    }

    mutating func validateInterpolation(_ segments: [IRInterpolationSegment], range: SourceRange) {
        for segment in segments {
            switch segment {
            case .literal:
                break
            case .expression(let expression), .formatted(let expression, _), .shellEscapedExpression(let expression):
                validate(expression, range: range, context: .valueExpression)
            case .conditional(let condition, let then, let otherwise):
                validate(condition, range: range, context: .valueExpression)
                validateInterpolation(then, range: range)
                validateInterpolation(otherwise, range: range)
            case .forEach(let variable, let collection, let body):
                if variable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    invalidIR("interpolated string loop has an empty variable", range: range)
                }
                validate(collection, range: range, context: .valueExpression)
                validateInterpolation(body, range: range)
            }
            if case .formatted(_, let formatter) = segment,
               formatter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                invalidIR("interpolated string formatter is empty", range: range)
            }
        }
    }

    mutating func validate(_ invoke: InvokeIR, range: SourceRange, context: Context) {
        let toolID = invoke.toolID.trimmingCharacters(in: .whitespacesAndNewlines)
        if toolID.isEmpty {
            invalidIR("invoke has an empty tool id", range: range)
        }
        var seenKeys: Set<String> = []
        for argument in invoke.arguments {
            let key = argument.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty {
                invalidIR("invoke \(toolID.isEmpty ? "<empty>" : toolID) has an empty argument key", range: range)
            } else if !seenKeys.insert(key).inserted {
                invalidIR("invoke \(toolID) repeats argument \(key)", range: range)
            }
            validate(argument.value, range: range, context: context)
        }

        guard toolID.hasPrefix("workflow:") else { return }
        let structName = String(toolID.dropFirst("workflow:".count))
        guard let target = workflowsByStructName[structName] else { return }
        let provided = Set(invoke.arguments.map(\.key))
        let missing = target.parameters
            .map(\.name)
            .filter { !provided.contains($0) }
        if !missing.isEmpty {
            invalidIR(
                "workflow invoke \(toolID) is missing argument\(missing.count == 1 ? "" : "s") \(missing.joined(separator: ", "))",
                range: range)
        }
    }

    mutating func invalidIR(_ message: String, range: SourceRange) {
        diagnostics.append(Diagnostic.error(.invalidIR, message: message, range: range))
    }

    mutating func matchSemantic(_ message: String, range: SourceRange) {
        diagnostics.append(Diagnostic.error(.matchBranchSemantic, message: message, range: range))
    }

    func concreteRange(_ range: SourceRange, fallback: SourceRange) -> SourceRange {
        if range == .unknown {
            return fallback == .unknown ? SourceRange(file: sourceFile, line: 0, column: 1) : fallback
        }
        return range
    }

    func patternKey(_ pattern: IRPattern) -> String {
        switch pattern {
        case .literal(let literal):
            return "literal:\(literalKey(literal))"
        case .enumValue(let value, kind: _):
            return "enum:\(value)"
        case .wildcard:
            return "wildcard"
        }
    }

    func patternLabel(_ pattern: IRPattern) -> String {
        switch pattern {
        case .literal(let literal):
            return literalKey(literal)
        case .enumValue(let value, kind: _):
            return value
        case .wildcard:
            return "wildcard"
        }
    }

    func literalKey(_ literal: IRLiteral) -> String {
        switch literal {
        case .string(let value):
            return value
        case .number(let value):
            return "\(value)"
        case .boolean(let value):
            return "\(value)"
        case .money(let value, currency: let currency):
            return "\(value) \(currency)"
        case .duration(let value):
            return "\(value)"
        case .date(let value), .dateTime(let value):
            return "\(value.timeIntervalSince1970)"
        case .enumValue(let value, kind: let kind):
            return "\(kind).\(value)"
        }
    }

    func logicalName(_ op: LogicalOp) -> String {
        switch op {
        case .and: return "and"
        case .or: return "or"
        case .not: return "not"
        }
    }

    func throwIfNeeded() throws {
        guard !diagnostics.isEmpty else { return }
        throw IRValidationError.diagnostics(diagnostics)
    }
}
