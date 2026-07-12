import Foundation
import MeridianRuntime

public struct Verbalizer: Sendable {
    public let model: VerbalizerModel
    private let trace: ParserTrace
    private let invokeInverter: InvokeInverter

    public init(model: VerbalizerModel, trace: ParserTrace = .shared) {
        self.model = model
        self.trace = trace
        self.invokeInverter = InvokeInverter(symbols: model.symbols)
    }

    private var grammar: FixedGrammar { model.lexicon.grammar }
    private var surface: FixedVerbalizerSurface { grammar.verbalizer }
    private var statement: FixedStatementKeywords { grammar.statement }

    public func verbalize() throws -> String {
        try validateCanonicalLexiconMarkers()
        try IRValidator.validate(model.workflows, sourceFile: model.sourceFileName, trace: trace)
        trace.log(.verbalizer, "verbalizing \(model.workflows.count) workflow(s)")
        var chunks: [String] = []
        if let frontmatter = verbalizeFrontmatter() {
            chunks.append(frontmatter)
        }
        let inlineDefinitions = model.loweredDefinitions.filter(\.isInline)
        if !inlineDefinitions.isEmpty {
            chunks.append(inlineDefinitions.map(verbalizeDefinition).joined(separator: "\n"))
        }
        chunks.append(contentsOf: model.workflows.filter(shouldEmitWorkflow).map(verbalizeWorkflow))
        return chunks.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private func validateCanonicalLexiconMarkers() throws {
        let missing = [
            ("empty markers", model.lexicon.emptyMarkers.isEmpty),
            ("filled markers", model.lexicon.filledMarkers.isEmpty),
            ("sort-by markers", model.lexicon.sortByMarkers.isEmpty),
        ].compactMap { name, isEmpty in isEmpty ? name : nil }
        guard !missing.isEmpty else { return }
        throw CompilerError.diagnostics([
            Diagnostic.error(
                .emptyLexiconMarkers,
                message: "lexicon marker collection\(missing.count == 1 ? "" : "s") empty: \(missing.joined(separator: ", "))",
                range: SourceRange(file: model.sourceFileName, line: 0, column: 1),
                help: "Provide at least one marker in each listed collection before canonical verbalization."
            )
        ])
    }

    public func verbalize(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(let literal):
            return CanonicalForms.literal(literal)
        case .constantRef(let name):
            return surface.definiteArticle + CanonicalForms.words(fromIdentifier: name)
        case .identifierRef(let name):
            return CanonicalForms.words(fromIdentifier: name)
        case .instanceRef(let name):
            return surface.definiteArticle + CanonicalForms.words(fromIdentifier: name)
        case .propertyAccess(let base, let propertyName):
            return possessive(base: base, property: propertyName)
        case .relationTraversal(let base, let relationName, let target):
            if let target {
                return "\(verbalize(base)) \(CanonicalForms.words(fromIdentifier: relationName)) \(verbalize(target))"
            }
            return "\(verbalize(base)) \(CanonicalForms.words(fromIdentifier: relationName))"
        case .comparison(let lhs, let op, let rhs):
            return verbalizeComparison(lhs, op, rhs)
        case .logical(let op, let operands):
            return verbalizeLogical(op, operands)
        case .envVar(let name):
            return surface.envVarPrefix + name
        case .nowExpression:
            return surface.nowKeyword
        case .invocation(let invoke):
            return invokeInverter.surface(for: invoke, renderExpression: verbalize)
        case .interpolatedString(let segments):
            return CanonicalForms.quoted(interpolationText(segments))
        case .recordList(let fields, let rows):
            let header = fields.map(CanonicalForms.words(fromIdentifier:)).joined(separator: surface.tableCellSeparator)
            let renderedRows = rows.map { row in
                row.map(verbalize).joined(separator: surface.tableCellSeparator)
            }
            return ([header] + renderedRows).joined(separator: surface.recordListSeparator)
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return surface.definiteArticle
                + CanonicalForms.words(fromIdentifier: valueColumn)
                + grammar.tableLookup.correspondingToMarker
                + CanonicalForms.words(fromIdentifier: keyColumn)
                + " \(verbalize(key))"
                + grammar.tableLookup.inTableMarker
                + CanonicalForms.words(fromIdentifier: table)
        case .definitionPredicate(let functionName, let subject):
            if let record = definitionRecord(functionName: functionName) {
                return verbalize(subject) + surface.definitionPredicateCopula + record.adjective
            }
            return verbalize(subject) + surface.definitionPredicateCopula + CanonicalForms.words(fromIdentifier: functionName)
        case .quantified(let quantifier):
            return verbalizeQuantifier(quantifier)
        case .description(let description):
            return verbalizeDescription(description)
        case .aggregate(let kind, let description):
            switch kind {
            case .count:
                return surface.aggregateCountPrefix + verbalizeDescription(description)
            case .list:
                return surface.aggregateListPrefix + verbalizeDescription(description)
            }
        case .superlative(let superlative):
            let direction = superlative.ascending
                ? surface.superlativeSmallestLabel
                : surface.superlativeLargestLabel
            return surface.definiteArticle
                + direction
                + " \(verbalizeDescription(superlative.description))"
                + grammar.passiveByMarker
                + CanonicalForms.words(fromIdentifier: superlative.sortPath)
        case .eventPattern(let pattern):
            return verbalizeEventPattern(pattern)
        case .traceTemporal(let temporal):
            return verbalizeTraceTemporal(temporal)
        case .traceStatistical(let statistical):
            return verbalizeTraceStatistical(statistical)
        }
    }

    public func verbalize(_ prim: IRPrimitive) -> String {
        switch prim {
        case .invoke(let invoke):
            return verbalizeInvoke(invoke)
        case .bind(let bind):
            if let note = verbalizeCompoundNote(bind) {
                return note
            }
            let keyword = bind.isRebind
                ? statement.rebindPrefix.trimmingCharacters(in: .whitespaces)
                : statement.bindPrefix.trimmingCharacters(in: .whitespaces)
            if !bind.isRebind,
               case .recordList(let fields, let rows) = bind.expression {
                return verbalizeDataTable(name: bind.name, fields: fields, rows: rows)
            }
            if case .interpolatedString(let segments) = bind.expression {
                return ([ "\(keyword) \(bind.name)\(surface.bindEqualsMarker)", "\(CanonicalForms.indent)```" ]
                    + CanonicalForms.indented(interpolationText(segments).components(separatedBy: "\n"))
                    + [ "\(CanonicalForms.indent)```" ])
                    .joined(separator: "\n")
            }
            return CanonicalForms.sentence("\(keyword) \(bind.name)\(surface.bindEqualsMarker)\(verbalize(bind.expression))")
        case .branch(let branch):
            return verbalizeBranch(branch)
        case .iterate(let iterate):
            return verbalizeIterate(iterate)
        case .assert(let assertion):
            return verbalizeAssert(assertion)
        case .emit(let emit):
            return verbalizeEmit(emit)
        case .wait(let wait):
            return verbalizeWait(wait)
        case .commit(let commit):
            if let label = commit.label {
                return CanonicalForms.sentence("\(statement.commitWithLabelPrefix)\(CanonicalForms.quoted(label))")
            }
            return "\(statement.commit)."
        case .recover(let recover):
            return verbalizeRecover(recover)
        case .simultaneously(let simultaneously):
            return verbalizeSimultaneously(simultaneously)
        case .aiJudgment(let judgment):
            return verbalizeJudgment(judgment)
        case .aiAutonomy(let autonomy):
            return verbalizeAutonomy(autonomy)
        case .complete(let complete):
            if let reason = complete.reason {
                return "\(statement.completeWithReasonPrefix)\(CanonicalForms.quoted(reason))."
            }
            return "\(statement.complete)."
        }
    }

    /// Reprint the INFORM7 §2.9 compound note surface for its desugared IR.
    /// Lowering desugars `proceed, and note "<text>" in the <binding>` to a
    /// `rebind <binding> = {{ binding }}<text>`; when a rebind's value is exactly
    /// that shape (an interpolated string appending a literal to the same
    /// binding), print the canonical note form so it round-trips instead of
    /// leaking the fenced-template rebind surface.
    private func verbalizeCompoundNote(_ bind: BindIR) -> String? {
        guard bind.isRebind,
              case .interpolatedString(let segments) = bind.expression,
              segments.count == 2,
              case .expression(.identifierRef(let name)) = segments[0],
              case .literal(let text) = segments[1],
              name == bind.name else { return nil }
        return CanonicalForms.sentence(
            grammar.compoundNoteIntroducer
                + CanonicalForms.quoted(text)
                + grammar.compoundNoteInMarker
                + surface.definiteArticle
                + CanonicalForms.words(fromIdentifier: bind.name))
    }

    private func verbalizeWorkflow(_ workflow: IRWorkflow) -> String {
        let header: String
        let whenPrefix = grammar.ruleMarkers.whenPrefix
        if workflow.name.hasPrefix(whenPrefix) {
            // Synthetic `when …` trigger workflows are parameter-less. Emitting
            // `To when a patient is …:` would reparse as a phrase with a
            // `patient` parameter slot. Drop articles in the header so the
            // round-trip keeps `parameters: []`.
            header = surface.workflowHeaderPrefix + stripArticlesForWhenHeader(workflowFallbackName(workflow)) + ":"
        } else if let pattern = invokeInverter.phrase(for: workflow) {
            header = surface.workflowHeaderPrefix + pattern.displayText + ":"
        } else {
            header = surface.workflowHeaderPrefix + workflowFallbackName(workflow) + ":"
        }
        let body = blockLines(workflow.body)
        return ([header] + CanonicalForms.indented(body)).joined(separator: "\n")
    }

    private func stripArticlesForWhenHeader(_ name: String) -> String {
        name
            .split(separator: " ", omittingEmptySubsequences: false)
            .filter { !model.lexicon.articles.contains($0.lowercased()) }
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func verbalizeFrontmatter() -> String? {
        guard let metadata = model.metadata, !metadata.entries.isEmpty else { return nil }
        var lines = ["---"]
        var emittedTools = false
        for entry in metadata.entries {
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedKey = normalizeFrontmatterKey(entry.key)
            if SkillFrontmatter.toolKeyAliases.contains(normalizedKey) {
                emittedTools = true
                let tools = mergedFrontmatterList(value, adding: model.toolsUsed)
                lines.append("\(entry.key):")
                for item in tools {
                    lines.append("  - \(frontmatterListItem(item))")
                }
                continue
            }
            if value.contains("\n") {
                if SkillFrontmatter.listFormattedKeys.contains(normalizedKey) {
                    lines.append("\(entry.key):")
                    for item in value.components(separatedBy: "\n").filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        lines.append("  - \(frontmatterListItem(item))")
                    }
                } else {
                    lines.append("\(entry.key): |")
                    lines += CanonicalForms.indented(value.components(separatedBy: "\n"))
                }
            } else {
                lines.append("\(entry.key): \(value)")
            }
        }
        if !emittedTools, !model.toolsUsed.isEmpty {
            lines.append("tools:")
            for item in model.toolsUsed {
                lines.append("  - \(frontmatterListItem(item))")
            }
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    private func mergedFrontmatterList(_ value: String, adding extra: [String]) -> [String] {
        var seen: Set<String> = []
        var merged: [String] = []
        for item in value.components(separatedBy: "\n") + extra {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            merged.append(trimmed)
        }
        return merged
    }

    private func normalizeFrontmatterKey(_ key: String) -> String {
        key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func frontmatterListItem(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\""), trimmed.hasSuffix("\"") { return trimmed }
        return CanonicalForms.quoted(trimmed)
    }

    private func shouldEmitWorkflow(_ workflow: IRWorkflow) -> Bool {
        guard model.metadata != nil,
              !SkillFrontmatter(model.metadata).triggers.isEmpty else {
            return true
        }
        return !isSyntheticTriggerWorkflow(workflow)
    }

    private func isSyntheticTriggerWorkflow(_ workflow: IRWorkflow) -> Bool {
        let whenPrefix = grammar.ruleMarkers.whenPrefix
        guard workflow.parameters.isEmpty,
              workflow.name.hasPrefix(whenPrefix),
              workflow.name.hasSuffix(surface.syntheticTriggerFiresSuffix),
              workflow.body.statements.count == 2,
              case .wait(let wait) = workflow.body.statements[0],
              case .event(let eventName, nil) = wait.condition,
              case .emit(let emit) = workflow.body.statements[1],
              emit.eventID == "trigger.\(eventName).fired" else {
            return false
        }
        let metadataSpecs = Set(SkillFrontmatter(model.metadata).triggers)
        let spec = emit.payload.first { $0.key == "spec" }?.value
        if case .literal(.string(let value)) = spec {
            return metadataSpecs.contains(value)
        }
        return false
    }

    private func workflowFallbackName(_ workflow: IRWorkflow) -> String {
        if !workflow.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return workflow.name
        }
        guard !workflow.parameters.isEmpty else { return workflow.structName }
        let params = workflow.parameters.map { surface.workflowParamArticle + $0.kind.name }
            .joined(separator: surface.workflowParamJoiner)
        return CanonicalForms.words(fromIdentifier: workflow.structName) + surface.workflowWithJoiner + params
    }

    private func verbalizeDefinition(_ definition: LoweredDefinitionInfo) -> String {
        surface.definitionHeaderPrefix
            + definition.kind
            + surface.definitionCopulaMarker
            + definition.adjective
            + grammar.definitionIfMarker
            + verbalize(definition.body)
            + "."
    }

    private func verbalizeDataTable(name: String, fields: [String], rows: [[IRExpression]]) -> String {
        var lines = [surface.dataTableDirectivePrefix + name + surface.dataTableDirectiveSuffix]
        lines.append(markdownRow(fields))
        lines.append(markdownRow(fields.map { String(repeating: "-", count: max(3, $0.count)) }))
        for row in rows {
            lines.append(markdownRow(row.map(verbalizeDataCell)))
        }
        return lines.joined(separator: "\n")
    }

    private func markdownRow(_ cells: [String]) -> String {
        surface.tableRowPrefix + cells.map(escapeTableCell).joined(separator: surface.tableCellSeparator) + surface.tableRowSuffix
    }

    private func escapeTableCell(_ cell: String) -> String {
        cell.replacingOccurrences(of: "\n", with: " ")
    }

    private func verbalizeDataCell(_ expression: IRExpression) -> String {
        if case .literal(let literal) = expression {
            return CanonicalForms.literal(literal)
        }
        return CanonicalForms.quoted(verbalize(expression))
    }

    private func verbalizeInvoke(_ invoke: InvokeIR) -> String {
        if invoke.toolID == "shell.run",
           let command = invoke.arguments.first(where: { $0.key == "command" })?.value {
            var text = CanonicalForms.backticked(shellCommand(command))
            if let comment = invoke.comment, !comment.isEmpty {
                text += surface.shellCommentSeparator + comment
            }
            if let binding = invoke.resultBinding {
                return CanonicalForms.sentence(statement.bindPrefix + binding + surface.bindEqualsMarker + text)
            }
            return CanonicalForms.sentence(text)
        }
        let surfaceText = invokeInverter.surface(for: invoke, renderExpression: verbalize)
        if let binding = invoke.resultBinding {
            return CanonicalForms.sentence(statement.bindPrefix + binding + surface.bindEqualsMarker + surfaceText)
        }
        return CanonicalForms.sentence(surfaceText)
    }

    private func verbalizeBranch(_ branch: BranchIR) -> String {
        switch branch.condition {
        case .predicate(let condition):
            var lines = ["\(statement.ifPrefix)\(verbalize(condition)),"]
            lines += CanonicalForms.indented(blockLines(branch.thenBlock))
            if let unknownBlock = branch.unknownBlock {
                lines.append(statement.unknownWhetherPrefix.trimmingCharacters(in: .whitespaces) + ":")
                lines += CanonicalForms.indented(blockLines(unknownBlock))
            }
            if let elseBlock = branch.elseBlock {
                lines.append(statement.otherwiseCommaKeyword)
                lines += CanonicalForms.indented(blockLines(elseBlock))
            }
            return lines.joined(separator: "\n")
        case .match(let expression, let cases):
            var lines = ["\(statement.branchOnPrefix)\(verbalize(expression)):"]
            for branchCase in cases {
                lines.append(CanonicalForms.indent + "\(verbalize(branchCase.pattern)):")
                lines += CanonicalForms.indented(blockLines(branchCase.block), depth: 2)
            }
            if !branch.thenBlock.statements.isEmpty {
                lines.append(CanonicalForms.indent + statement.matchOtherwiseLabel)
                lines += CanonicalForms.indented(blockLines(branch.thenBlock), depth: 2)
            }
            return lines.joined(separator: "\n")
        }
    }

    private func verbalizeIterate(_ iterate: IterateIR) -> String {
        let iteration = grammar.iterationMarkers
        let header: String
        switch iterate.mode {
        case .overCollection(let parameter, _, let collection):
            if let refined = bareIterationCollection(parameter: parameter, collection: collection, refinement: iterate.source) {
                header = "\(statement.forEachPrefix)\(refined),"
            } else {
                header = "\(statement.forEachPrefix)\(parameter)\(iteration.collectionInMarker)\(verbalize(collection))\(refinementSuffix(iterate.source)),"
            }
        case .whileCondition(let condition):
            header = "\(statement.whilePrefix)\(verbalize(condition)),"
        case .untilCondition(let condition):
            header = "\(statement.untilPrefix)\(verbalize(condition)),"
        }
        return ([header] + CanonicalForms.indented(blockLines(iterate.body))).joined(separator: "\n")
    }

    private func bareIterationCollection(parameter: String, collection: IRExpression, refinement: IRIterationRefinement?) -> String? {
        guard let refinement,
              case .identifierRef(let collectionName) = collection,
              normalizedIdentifier(collectionName) == normalizedIdentifier(model.lexicon.pluralize(parameter)) else {
            return nil
        }
        let iteration = grammar.iterationMarkers
        let andMarker = grammar.booleanConnectors.andMarker
        var text = CanonicalForms.words(fromIdentifier: collectionName)
        if let take = refinement.take {
            text = iteration.firstPrefix + "\(take) \(text)"
        }
        if !refinement.filters.isEmpty {
            text += iteration.whoseMarker + refinement.filters
                .map { verbalizeDescriptionFilter($0, elementVar: parameter) }
                .joined(separator: andMarker)
        }
        if let sort = refinement.sort {
            let direction = sort.ascending ? surface.sortAscendingLabel : surface.sortDescendingLabel
            text += sortByMarker()
                + CanonicalForms.words(fromIdentifier: sort.path)
                + surface.sortDirectionComma
                + direction
        }
        return text
    }

    private func refinementSuffix(_ refinement: IRIterationRefinement?) -> String {
        guard let refinement else { return "" }
        let iteration = grammar.iterationMarkers
        let andMarker = grammar.booleanConnectors.andMarker
        var parts: [String] = []
        if !refinement.filters.isEmpty {
            let whose = iteration.whoseMarker.trimmingCharacters(in: .whitespaces)
            parts.append(whose + " " + refinement.filters.map(verbalize).joined(separator: andMarker))
        }
        if let sort = refinement.sort {
            let direction = sort.ascending ? surface.sortAscendingLabel : surface.sortDescendingLabel
            parts.append(surface.sortByCompactPrefix
                + CanonicalForms.words(fromIdentifier: sort.path)
                + surface.sortDirectionComma
                + direction)
        }
        if let take = refinement.take {
            parts.append(iteration.firstPrefix.trimmingCharacters(in: .whitespaces) + " \(take)")
        }
        return parts.isEmpty ? "" : " " + parts.joined(separator: " ")
    }

    private func sortByMarker() -> String {
        model.lexicon.sortByMarkers.first ?? surface.sortByMarker
    }

    private func verbalizeAssert(_ assertion: AssertIR) -> String {
        // Checklist / contract asserts store the authored predicate in
        // `message` as `Expected <text>`. Prefer that surface only when the
        // lowered condition is opaque (would not reparse identically). Do not
        // prefer it for permission-softened `or(…)` asserts — the message is
        // only the original check, not the softened condition.
        //
        // Do not emit `# assertion message: …` comments. Comments are dropped
        // on reparse, so they break the V(parse(V(ir))) string fixpoint even
        // when SEM-8-03 IR equality still holds (IREquality ignores messages).
        let condition = verbalize(assertion.condition)
        let authored = assertion.message.flatMap(assertMessagePredicate)
        let assertSurface: String
        if let authored, prefersAuthoredAssertSurface(assertion.condition) {
            assertSurface = authored
        } else {
            assertSurface = condition
        }
        if assertion.monitored {
            // A monitored assert is always a statistical predicate (the only
            // condition `monitoredAssertConfig` marks monitored) and, per
            // lowering, can never carry an `otherwise` block. The cadence /
            // blocking markers ride inside the verbalized statistical condition
            // itself. Emit the assertion prefix so the line reparses as a
            // monitored assert: a *bare* statistical predicate is only a valid
            // statement inside a checklist/monitor section, not in the flat
            // procedure the verbalizer emits, so a prefix-less form would fall
            // through to phrase resolution (MER2001) and break the round trip.
            return CanonicalForms.sentence(surface.assertPrefix + assertSurface)
        }
        if let otherwise = assertion.otherwiseAction {
            // Authored/parser surface is `assert X otherwise:` (colon), not the
            // branch form `otherwise,`. Same FixedGrammar label as match default.
            let otherwiseLabel = statement.matchOtherwiseLabel
            var lines = [surface.assertPrefix + assertSurface + " \(otherwiseLabel)"]
            lines += CanonicalForms.indented(blockLines(otherwise))
            return lines.joined(separator: "\n")
        }
        return CanonicalForms.sentence(surface.assertPrefix + assertSurface)
    }

    private func assertMessagePredicate(_ message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        guard lower.hasPrefix(surface.assertOpacityExpectedPrefix) else { return nil }
        let afterExpected = trimmed.dropFirst(surface.assertOpacityExpectedPrefix.count)
        // Reject glued tokens like `ExpectedFoo`; bare `Expected` / `Expected `
        // (whitespace-only remainder) intentionally yield nil.
        if let first = afterExpected.first, !first.isWhitespace {
            return nil
        }
        let predicate = String(afterExpected)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return predicate.isEmpty ? nil : predicate
    }

    private func prefersAuthoredAssertSurface(_ expression: IRExpression) -> Bool {
        switch expression {
        case .quantified(let quantifier):
            guard let body = quantifier.body else { return false }
            return isOpaqueQuantifierBody(body)
        case .logical(let op, let operands):
            // Softened permission asserts are `or(original, permission)` — keep
            // the verbalized condition, not the original Expected message.
            if case .or = op, operands.count > 1 { return false }
            return operands.contains(where: prefersAuthoredAssertSurface)
        case .propertyAccess, .identifierRef:
            return true
        case .comparison(_, let op, let rhs):
            return isOpaqueQuantifierBody(.comparison(.identifierRef(name: "_"), op, rhs))
        case .definitionPredicate, .literal, .constantRef, .instanceRef,
             .relationTraversal, .envVar, .nowExpression, .invocation,
             .interpolatedString, .recordList, .tableLookup, .description,
             .aggregate, .superlative, .eventPattern, .traceTemporal, .traceStatistical:
            return false
        }
    }

    private func isOpaqueQuantifierBody(_ expression: IRExpression) -> Bool {
        switch expression {
        case .propertyAccess:
            return true
        case .comparison(_, let op, let rhs):
            if case .identifierRef(let name) = rhs,
               name.contains("(") || name.contains("`") || name.contains("/") {
                return true
            }
            if case .equal = op, case .identifierRef(let name) = rhs,
               name.count > 24, name.contains(where: { $0.isUppercase }) {
                return true
            }
            return false
        case .definitionPredicate, .logical, .literal, .constantRef, .identifierRef,
             .instanceRef, .relationTraversal, .envVar, .nowExpression, .invocation,
             .interpolatedString, .recordList, .tableLookup, .quantified,
             .description, .aggregate, .superlative, .eventPattern, .traceTemporal, .traceStatistical:
            return false
        }
    }

    private func verbalizeEmit(_ emit: EmitIR) -> String {
        guard !emit.payload.isEmpty else {
            return CanonicalForms.sentence(statement.emitPrefix + emit.eventID)
        }
        let args = emit.payload.map { "\($0.key)\(surface.bindEqualsMarker)\(verbalize($0.value))" }.joined(separator: ", ")
        return CanonicalForms.sentence(statement.emitPrefix + emit.eventID + surface.emitWithMarker + args)
    }

    private func verbalizeWait(_ wait: WaitIR) -> String {
        switch wait.condition {
        case .duration(let duration):
            return CanonicalForms.sentence(statement.waitPrefix + CanonicalForms.duration(duration))
        case .signal(let signal):
            return CanonicalForms.sentence(statement.waitPrefix + grammar.waitSignalIntroducer + CanonicalForms.quoted(signal))
        case .approval(let subject, let role):
            return CanonicalForms.sentence(
                statement.waitPrefix
                    + grammar.waitApprovalOfIntroducer
                    + verbalize(subject)
                    + grammar.waitApprovalFromMarker
                    + role
            )
        case .event(let eventID, let matching):
            if let matching {
                return CanonicalForms.sentence(
                    statement.waitPrefix
                        + grammar.waitEventIntroducer
                        + eventID
                        + grammar.waitMatchingMarker
                        + verbalize(matching)
                )
            }
            return CanonicalForms.sentence(statement.waitPrefix + grammar.waitEventIntroducer + eventID)
        case .choice(_, let options):
            let rendered = options.map(CanonicalForms.quoted).joined(separator: ", ")
            let intro = grammar.choiceGateIntroducers[0]
            return CanonicalForms.sentence(intro + rendered)
        }
    }

    private func verbalizeRecover(_ recover: RecoverIR) -> String {
        let attached = blockLines(recover.attachedTo)
        let header: String
        switch recover.pattern {
        case .anyError:
            header = statement.recoverFromPrefix + surface.recoverAnyPattern + ":"
        case .named(let name):
            header = statement.recoverFromPrefix + CanonicalForms.quoted(name) + ":"
        case .typed(let kind):
            header = statement.recoverFromPrefix + kind.name + ":"
        case .predicate(let predicate):
            header = statement.recoverWherePrefix + verbalize(predicate) + ":"
        }
        return (attached + [header] + CanonicalForms.indented(blockLines(recover.handler))).joined(separator: "\n")
    }

    private func verbalizeSimultaneously(_ simultaneously: SimultaneouslyIR) -> String {
        if simultaneously.detached, simultaneously.branches.count == 1 {
            let body = blockLines(simultaneously.branches[0])
            if body.count == 1 {
                return grammar.backgroundSpawnIntroducers[0] + body[0]
            }
        }
        let header = simultaneously.detached
            ? surface.backgroundDetachedSimultaneouslyHeader
            : statement.simultaneouslyHeader
        var lines = [header]
        for branch in simultaneously.branches {
            lines += CanonicalForms.indented(blockLines(branch))
        }
        return lines.joined(separator: "\n")
    }

    private func verbalizeJudgment(_ judgment: AIJudgmentIR) -> String {
        let textLines = judgment.text.components(separatedBy: "\n")
        // `components(separatedBy:)` always yields at least one element.
        let goal = aiHeaderGoal(textLines[0])
        var lines = [grammar.judgmentIntroducers[0] + goal + ":"]
        let embeddedBody = Array(textLines.dropFirst())
        if !embeddedBody.isEmpty {
            lines += CanonicalForms.indented(normalizeAIBodyLines(embeddedBody.joined(separator: "\n")))
        }
        if let guidance = judgment.guidance, !guidance.isEmpty {
            lines += CanonicalForms.indented(normalizeAIBodyLines(guidance))
        }
        return lines.joined(separator: "\n")
    }

    private func verbalizeAutonomy(_ autonomy: AIAutonomyIR) -> String {
        let autonomyMarkers = grammar.autonomyMarkers
        var modifiers: [String] = []
        if let until = autonomy.autonomy.until {
            modifiers.append(autonomyMarkers.until + " \(verbalize(until))")
        }
        if let unless = autonomy.autonomy.unless {
            modifiers.append(autonomyMarkers.unless + " \(verbalize(unless))")
        }
        modifiers.append(autonomyMarkers.replanAfter[0] + " \(autonomy.autonomy.replanAfterFailures)" + surface.autonomyFailuresSuffix)
        modifiers.append(autonomyMarkers.maxSteps[1] + " \(autonomy.autonomy.maxSteps)" + surface.autonomyStepsSuffix)
        // Parser form is `with autonomy <opts>:` + indented body. Putting the
        // goal after a comma on the header line does not reparse (body becomes
        // empty on the next pass).
        var lines = [grammar.autonomyMarker + " \(modifiers.joined(separator: " ")):"]
        let bodyText = autonomy.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !bodyText.isEmpty {
            lines += CanonicalForms.indented(normalizeAIBodyLines(bodyText))
        }
        if let guidance = autonomy.guidance, !guidance.isEmpty {
            lines += CanonicalForms.indented(normalizeAIBodyLines(guidance))
        }
        return lines.joined(separator: "\n")
    }

    private func aiHeaderGoal(_ text: String) -> String {
        var goal = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while goal.hasSuffix(":") {
            goal = String(goal.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return goal
    }

    /// Strip leading markdown bullets so judgment/autonomy body lines are a
    /// fixpoint: reparse drops `- ` markers that IREquality already ignores.
    private func normalizeAIBodyLines(_ text: String) -> [String] {
        text.components(separatedBy: "\n").map { line in
            var trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("- ") {
                trimmed = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return trimmed
        }
    }

    private func verbalizeComparison(_ lhs: IRExpression, _ op: ComparisonOp, _ rhs: IRExpression) -> String {
        switch op {
        case .isEmpty, .isNotEmpty:
            return "\(verbalize(lhs)) \(CanonicalForms.comparison(op))"
        case .withinPast, .withinFuture:
            return "\(verbalize(lhs)) \(CanonicalForms.comparison(op)) \(verbalize(rhs))"
        case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual,
             .oneOf, .contains, .startsWith, .endsWith, .withinDuration,
             .matchesPattern, .identifies:
            return "\(verbalize(lhs)) \(CanonicalForms.comparison(op)) \(verbalize(rhs))"
        }
    }

    private func verbalizeEventPattern(_ pattern: EventPatternIR) -> String {
        // `TraceEventPatternGrammar.parse`'s outcome-marker scan only accepts
        // the outcome verb as the very last token of the clause (a `whose …`
        // payload predicate, if any, must precede it — `subject whose … is …
        // outcome`); an outcome verb followed by a trailing `whose` clause
        // does not match either the infix or suffix marker form and silently
        // falls through to the quantifier `no …` ambiguity on reparse. So the
        // predicate must be verbalized before the outcome verb, not after.
        let negation = pattern.negated ? grammar.traceEventNegationPrefix : ""
        var text = negation + verbalizeEventPatternSubject(pattern)
        if let payloadPredicate = pattern.payloadPredicate {
            text += " " + grammar.iterationMarkers.whoseMarker.trimmingCharacters(in: .whitespaces) + " " + verbalize(payloadPredicate)
        }
        text += " " + pattern.outcome.rawValue
        return text
    }

    private func verbalizeEventPatternSubject(_ pattern: EventPatternIR) -> String {
        let subject: String
        switch pattern.subject {
        case .step(let name):
            subject = surface.definiteArticle + name + " step"
        case .named(let name):
            subject = surface.definiteArticle + name
        }
        return subject
    }

    private func verbalizeTraceTemporal(_ temporal: TraceTemporalIR) -> String {
        let scoped: (String) -> String = { body in
            switch temporal.scope {
            case .acrossAllRuns:
                return grammar.traceAcrossAllRunsMarker + body
            case .currentRun:
                return body
            }
        }
        switch temporal.kind {
        case .ever(let pattern):
            var subjectSide = verbalizeEventPatternSubject(pattern)
            if let payloadPredicate = pattern.payloadPredicate {
                subjectSide += " " + grammar.iterationMarkers.whoseMarker.trimmingCharacters(in: .whitespaces) + " " + verbalize(payloadPredicate)
            }
            return scoped(subjectSide + grammar.traceHasEverMarker + pattern.outcome.rawValue)
        case .withinWindow(let pattern, let duration):
            return scoped(verbalizeEventPattern(pattern) + grammar.traceWithinLastMarker + CanonicalForms.duration(duration))
        case .countInWindow(let pattern, let comparator, let duration):
            let comparatorText: String
            switch comparator {
            case .atLeast(let value): comparatorText = "at least \(value) times"
            case .atMost(let value): comparatorText = "at most \(value) times"
            case .exactly(let value): comparatorText = "exactly \(value) times"
            }
            return scoped(verbalizeEventPattern(pattern) + " " + comparatorText + grammar.traceWithinLastMarker + CanonicalForms.duration(duration))
        case .inARow(let pattern, let count):
            return scoped(verbalizeEventPattern(pattern) + " \(count)" + grammar.traceInARowSuffix)
        case .sinceLast(let anchor, let holds, _):
            // A negated event-pattern hold (`no <event> …`) must be verbalized
            // in the anchor-first surface form (`since the last <anchor>, no
            // <event> …`), not the default anchor-last form (`no <event> …
            // since the last <anchor>`): a condition starting with `no` is
            // ambiguous with the `no`-quantifier at the top of `parseClause`
            // (cookbook 2.7), so `no …` only parses correctly here when
            // `since the last` already claimed the clause first.
            if case .eventPattern(let pattern) = holds, pattern.negated {
                return scoped(grammar.traceSinceLastAnchorFirstMarker
                    + verbalizeEventPattern(anchor) + ", " + verbalize(holds))
            }
            return scoped(verbalize(holds) + grammar.traceSinceLastMarker + verbalizeEventPattern(anchor))
        }
    }

    private func verbalizeTraceStatistical(_ statistical: TraceStatisticalIR) -> String {
        let scoped: (String) -> String = { body in
            switch statistical.scope {
            case .acrossAllRuns:
                return grammar.traceAcrossAllRunsMarker + body
            case .currentRun:
                return body
            }
        }
        var subject: String
        switch statistical.pattern.subject {
        case .step(let name):
            subject = surface.definiteArticle + name + " step"
        case .named(let name):
            subject = surface.definiteArticle + name
        }
        if let payloadPredicate = statistical.pattern.payloadPredicate {
            subject += " " + grammar.iterationMarkers.whoseMarker.trimmingCharacters(in: .whitespaces) + " " + verbalize(payloadPredicate)
        }
        let outcome = statistical.outcome == .succeeds
            ? grammar.traceStatisticalSuccessKeyword
            : grammar.traceStatisticalFailureKeyword
        let bound: String
        switch statistical.bound {
        case .atLeast(let ratio):
            bound = grammar.traceStatisticalAtLeastMarker + percentText(ratio) + grammar.traceStatisticalPercentOfMarker
        case .atMost(let ratio):
            bound = grammar.traceStatisticalAtMostMarker + percentText(ratio) + grammar.traceStatisticalPercentOfMarker
        }
        let denominator = statistical.denominator == .runs
            ? grammar.traceStatisticalRunsWord
            : grammar.traceStatisticalOccurrencesWord
        var body = subject + " " + outcome + bound + denominator
        if let window = statistical.window {
            body += grammar.traceWithinLastMarker + CanonicalForms.duration(window)
        }
        if let cadence = statistical.monitorCadence {
            body += grammar.traceStatisticalCheckedEveryMarker + CanonicalForms.duration(cadence)
        }
        if statistical.blocking {
            body += grammar.traceStatisticalBlockingSuffix
        }
        return scoped(body)
    }

    private func percentText(_ ratio: Double) -> String {
        let percent = ratio * 100
        if percent.rounded() == percent {
            return "\(Int(percent))"
        }
        return "\(percent)"
    }

    private func verbalizeLogical(_ op: LogicalOp, _ operands: [IRExpression]) -> String {
        let connectors = grammar.booleanConnectors
        switch op {
        case .and:
            return operands.map(verbalize).joined(separator: connectors.andMarker)
        case .or:
            guard operands.count > 1 else { return operands.first.map(verbalize) ?? surface.falsyLiteral }
            return connectors.eitherPrefix + operands.map(verbalize).joined(separator: connectors.orMarker)
        case .not:
            return connectors.notPrefix + (operands.first.map(verbalize) ?? surface.truthyLiteral)
        }
    }

    private func verbalizeQuantifier(_ quantifier: QuantifierIR) -> String {
        let base = CanonicalForms.quantifier(quantifier.kind, noun: verbalizeDescription(quantifier.description))
        if let body = quantifier.body {
            if let phrase = quantifierBodyPhrase(body, elementVar: quantifier.description.elementVar) {
                return "\(base) \(phrase)"
            }
            if case .definitionPredicate(let functionName, let subject) = body,
               let record = definitionRecord(functionName: functionName),
               isLoopSubject(subject, elementVar: quantifier.description.elementVar)
                || isLoopSubject(unwrapLoopPropertySubject(subject, elementVar: quantifier.description.elementVar),
                                 elementVar: quantifier.description.elementVar) {
                return base + surface.definitionPredicateCopula + record.adjective
            }
            if case .propertyAccess(.identifierRef(let baseName), let property) = body,
               identifierMatches(baseName, quantifier.description.elementVar) {
                // Opaque boolean property (`orderHasInventoryReserved`) — emit
                // as `have <words>` so emptiness grammar can recover `has a`
                // only when the property is a plain noun; otherwise keep words.
                let words = CanonicalForms.words(fromIdentifier: property)
                if let stripped = stripLeadingHasWords(words) {
                    return "\(base) \(surface.quantifierBodyHaveMarker)\(stripped)"
                }
                return "\(base) \(surface.quantifierBodyHaveMarker)\(words)"
            }
            return "\(base) \(surface.quantifierBodyHaveMarker)\(verbalize(body))"
        }
        return base
    }

    private func unwrapLoopPropertySubject(_ expression: IRExpression, elementVar: String) -> IRExpression {
        // Lowering sometimes wraps the element as `<element>.<camelElement>`
        // when spaced vs camel loop-var keys disagree; treat that as the element.
        if case .propertyAccess(let base, let property) = expression,
           case .identifierRef(let baseName) = base,
           identifierMatches(baseName, elementVar),
           identifierMatches(property, elementVar) {
            return base
        }
        return expression
    }

    private func stripLeadingHasWords(_ words: String) -> String? {
        let lower = words.lowercased()
        // Bare `has` / `have` (no trailing space) are not stripable prefixes.
        // `CanonicalForms.words` collapses whitespace, so a `has ` / `have `
        // prefix always leaves a non-empty rest when it matches.
        for prefix in statement.possessionPrefixes where lower.hasPrefix(prefix) {
            return String(words.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func verbalizeDescription(_ description: DescriptionIR) -> String {
        let adjectiveFilters = description.filters.compactMap {
            definitionAdjectiveFilter($0, elementVar: description.elementVar)
        }
        // A relation-backed `.identifies` filter (`services owned by the
        // user`) must round trip through the same `<participle> by
        // <operand>` verb-clause surface `QuantifierGrammar`/
        // `DescriptionGrammar` parse it from — never through the generic
        // `whose <property> identifies <operand>` filter rendering below,
        // since "identifies" is a pure IR comparison tag with no parser-side
        // surface form (it can't be reparsed back into a comparison at all).
        let verbClauseFilters = description.filters.compactMap {
            verbClauseFilterText($0, elementVar: description.elementVar)
        }
        let residualFilters = description.filters.filter {
            definitionAdjectiveFilter($0, elementVar: description.elementVar) == nil
                && verbClauseFilterText($0, elementVar: description.elementVar) == nil
        }
        var text = ([adjectiveFilters.joined(separator: " "), descriptionHead(description)]
            .filter { !$0.isEmpty })
            .joined(separator: " ")
        if !verbClauseFilters.isEmpty {
            text += " " + verbClauseFilters.joined(separator: " " + grammar.booleanConnectors.andMarker.trimmingCharacters(in: .whitespaces) + " ")
        }
        if !residualFilters.isEmpty {
            let whose = grammar.iterationMarkers.whoseMarker
            let andMarker = grammar.booleanConnectors.andMarker
            text += whose + residualFilters
                .map { verbalizeDescriptionFilter($0, elementVar: description.elementVar) }
                .joined(separator: andMarker)
        }
        if let sort = description.sort {
            let direction = sort.ascending ? surface.sortAscendingLabel : surface.sortDescendingLabel
            text += sortByMarker()
                + CanonicalForms.words(fromIdentifier: sort.path)
                + " "
                + direction
        }
        if let take = description.take {
            text = surface.takeTheFirstPrefix + "\(take) \(text)"
        }
        return text
    }

    private func descriptionHead(_ description: DescriptionIR) -> String {
        if case .identifierRef(let name) = description.collection {
            return CanonicalForms.words(fromIdentifier: name)
        }
        return description.elementVar + surface.descriptionElementInMarker + verbalize(description.collection)
    }

    private func verbalizeDescriptionFilter(_ expression: IRExpression, elementVar: String) -> String {
        switch expression {
        case .comparison(let lhs, let op, let rhs):
            switch op {
            case .isEmpty, .isNotEmpty:
                return "\(verbalizeLoopRelative(lhs, elementVar: elementVar)) \(CanonicalForms.comparison(op))"
            case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual,
                 .oneOf, .contains, .startsWith, .endsWith, .withinDuration, .withinPast,
                 .withinFuture, .matchesPattern, .identifies:
                return "\(verbalizeLoopRelative(lhs, elementVar: elementVar)) \(CanonicalForms.comparison(op)) \(verbalizeLoopRelative(rhs, elementVar: elementVar))"
            }
        case .logical(let op, let operands):
            let connectors = grammar.booleanConnectors
            switch op {
            case .and:
                return operands.map { verbalizeDescriptionFilter($0, elementVar: elementVar) }
                    .joined(separator: connectors.andMarker)
            case .or:
                return connectors.eitherPrefix
                    + operands.map { verbalizeDescriptionFilter($0, elementVar: elementVar) }
                    .joined(separator: connectors.orMarker)
            case .not:
                return connectors.notPrefix
                    + (operands.first.map { verbalizeDescriptionFilter($0, elementVar: elementVar) } ?? surface.truthyLiteral)
            }
        case .definitionPredicate(let functionName, let subject):
            if let record = definitionRecord(functionName: functionName),
               isLoopSubject(subject, elementVar: elementVar) {
                return record.adjective
            }
            return verbalize(expression)
        case .literal, .constantRef, .identifierRef, .instanceRef, .propertyAccess,
             .relationTraversal, .envVar, .nowExpression, .invocation, .interpolatedString,
             .recordList, .tableLookup, .quantified, .description, .aggregate, .superlative,
             .eventPattern, .traceTemporal, .traceStatistical:
            return verbalizeLoopRelative(expression, elementVar: elementVar)
        }
    }

    private func verbalizeLoopRelative(_ expression: IRExpression, elementVar: String) -> String {
        switch expression {
        case .propertyAccess(.identifierRef(let base), let property) where identifierMatches(base, elementVar):
            // Spaced words, not raw camelCase: reparse of `totalAmount` vs
            // `total amount` otherwise oscillates across verbalize passes.
            return CanonicalForms.words(fromIdentifier: property)
        case .identifierRef(let name) where name == elementVar:
            return CanonicalForms.words(fromIdentifier: name)
        case .comparison, .logical, .definitionPredicate:
            return verbalizeDescriptionFilter(expression, elementVar: elementVar)
        case .literal, .constantRef, .identifierRef, .instanceRef, .propertyAccess,
             .relationTraversal, .envVar, .nowExpression, .invocation, .interpolatedString,
             .recordList, .tableLookup, .quantified, .description, .aggregate, .superlative,
             .eventPattern, .traceTemporal, .traceStatistical:
            return verbalize(expression)
        }
    }

    private func quantifierBodyPhrase(_ expression: IRExpression, elementVar: String) -> String? {
        guard case .comparison(let lhs, let op, _) = expression,
              case .propertyAccess(.identifierRef(let base), let property) = lhs,
              identifierMatches(base, elementVar) else {
            return nil
        }
        switch op {
        case .isNotEmpty:
            return emptinessBodyPhrase(isEmpty: false, property: property)
        case .isEmpty:
            return emptinessBodyPhrase(isEmpty: true, property: property)
        case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual,
             .oneOf, .contains, .startsWith, .endsWith, .withinDuration, .withinPast,
             .withinFuture, .matchesPattern, .identifies:
            return nil
        }
    }

    /// Quantifier-body emptiness surface from lexicon `emptyMarkers` /
    /// `filledMarkers`. Prefers a `have …` form so reparse hits the same
    /// emptiness production the parser already keys on.
    private func emptinessBodyPhrase(isEmpty: Bool, property: String) -> String {
        let markers = isEmpty ? model.lexicon.emptyMarkers : model.lexicon.filledMarkers
        let preferred = markers.first { $0.lowercased().contains("have") } ?? markers.first
        let verbPhrase = (preferred ?? (isEmpty ? " have no " : " have a "))
            .trimmingCharacters(in: .whitespaces)
        return "\(verbPhrase) \(CanonicalForms.words(fromIdentifier: property))"
    }

    private func isLoopSubject(_ expression: IRExpression, elementVar: String) -> Bool {
        if case .identifierRef(let name) = expression {
            return identifierMatches(name, elementVar)
        }
        return false
    }

    private func definitionAdjectiveFilter(_ expression: IRExpression, elementVar: String) -> String? {
        guard case .definitionPredicate(let functionName, let subject) = expression,
              let record = definitionRecord(functionName: functionName),
              isLoopSubject(subject, elementVar: elementVar) else {
            return nil
        }
        return record.adjective
    }

    /// Reverse a property-backed `.identifies` filter (`comparison(<loop
    /// var>.<property>, .identifies, <operand>)`) back into the declared
    /// verb's passive surface (`<pastParticiple> by <operand>`) that
    /// `DescriptionGrammar.parsePassiveClauseSuffix` parses it from. Returns
    /// `nil` when the filter isn't this shape or no declared verb covers the
    /// backing relation (falls back to the generic `whose` filter text).
    private func verbClauseFilterText(_ expression: IRExpression, elementVar: String) -> String? {
        guard case .comparison(let lhs, .identifies, let rhs) = expression,
              case .propertyAccess(let base, let propertyName) = lhs,
              isLoopSubject(base, elementVar: elementVar) else { return nil }
        guard let relationName = model.symbols.relationBackings.first(where: { _, backing in
            if case .property(_, let path) = backing { return path.lowercased() == propertyName.lowercased() }
            return false
        })?.key else { return nil }
        guard let verb = model.symbols.verbs.values.first(where: { $0.relation == relationName }) else { return nil }
        return verb.pastParticiple + grammar.passiveByMarker + verbalizeLoopRelative(rhs, elementVar: elementVar)
    }

    private func identifierMatches(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || normalizedIdentifier(lhs) == normalizedIdentifier(rhs)
    }

    private func normalizedIdentifier(_ value: String) -> String {
        CanonicalForms.words(fromIdentifier: value)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    private func verbalize(_ pattern: IRPattern) -> String {
        switch pattern {
        case .literal(let literal):
            return CanonicalForms.literal(literal)
        case .enumValue(let value, kind: _):
            return value
        case .wildcard:
            return statement.matchBranchCanonicalWildcard
        }
    }

    private func blockLines(_ block: IRBlock) -> [String] {
        var lines: [String] = []
        var index = 0
        let statements = block.statements
        while index < statements.count {
            let primitive = statements[index]
            // Choice gates lower to emit(ask.choice)+wait(.choice). Emit only
            // the wait's canonical `ask the user to choose between …` surface
            // so reparse rebuilds the same emit+wait pair.
            if case .emit(let emit) = primitive,
               emit.eventID == "ask.choice",
               index + 1 < statements.count,
               case .wait(let wait) = statements[index + 1],
               case .choice = wait.condition {
                lines += verbalizeWait(wait).components(separatedBy: "\n")
                index += 2
                continue
            }
            if case .emit(let emit) = primitive, emit.eventID == "ask.choice",
               let wait = choiceWaitFromEmit(emit) {
                lines += verbalizeWait(wait).components(separatedBy: "\n")
                index += 1
                continue
            }
            lines += verbalize(primitive).components(separatedBy: "\n")
            index += 1
        }
        return lines
    }

    private func choiceWaitFromEmit(_ emit: EmitIR) -> WaitIR? {
        let optionsValue = emit.payload.first { $0.key == "options" }?.value
        guard case .literal(.string(let emittedOptions)) = optionsValue else { return nil }
        let options = emittedOptions
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !options.isEmpty else { return nil }
        let rendered = options.map(CanonicalForms.quoted).joined(separator: ", ")
        let intro = grammar.choiceGateIntroducers[0]
        let prompt = intro + rendered + surface.choicePromptTerminator
        return WaitIR(condition: .choice(prompt: prompt, options: options), sourceRange: emit.sourceRange)
    }

    private func possessive(base: IRExpression, property: String) -> String {
        let prop = CanonicalForms.words(fromIdentifier: property)
        switch base {
        case .identifierRef(let name):
            return surface.definiteArticle + CanonicalForms.words(fromIdentifier: name) + surface.possessiveSuffix + prop
        case .propertyAccess, .literal, .constantRef, .instanceRef, .relationTraversal,
             .comparison, .logical, .envVar, .nowExpression, .invocation,
             .interpolatedString, .recordList, .tableLookup, .definitionPredicate,
             .quantified, .description, .aggregate, .superlative, .eventPattern, .traceTemporal, .traceStatistical:
            return verbalize(base) + surface.possessiveSuffix + prop
        }
    }

    private func definitionRecord(functionName: String) -> SymbolTable.DefinitionRecord? {
        model.symbols.definitions.values.first { $0.functionName == functionName }
    }

    private func shellCommand(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(.string(let command)):
            return command
        case .interpolatedString(let segments):
            return interpolationText(segments, holeStyle: .shell)
        case .literal, .constantRef, .identifierRef, .instanceRef, .propertyAccess,
             .relationTraversal, .comparison, .logical, .envVar, .nowExpression,
             .invocation, .recordList, .tableLookup, .definitionPredicate,
             .quantified, .description, .aggregate, .superlative, .eventPattern, .traceTemporal, .traceStatistical:
            return surface.shellHoleOpen + verbalize(expr) + surface.shellHoleClose
        }
    }

    private enum InterpolationHoleStyle {
        case template
        case shell
    }

    private func interpolationText(
        _ segments: [IRInterpolationSegment],
        holeStyle: InterpolationHoleStyle = .template
    ) -> String {
        let directives = grammar.templateDirectives
        return segments.map { segment in
            switch segment {
            case .literal(let value):
                return value
            case .expression(let expression), .shellEscapedExpression(let expression):
                return hole(verbalize(expression), style: holeStyle)
            case .conditional(let condition, let thenSegments, let otherwiseSegments):
                let thenText = interpolationText(thenSegments, holeStyle: holeStyle)
                let otherwiseText = interpolationText(otherwiseSegments, holeStyle: holeStyle)
                return "\(directives.ifPrefix)\(verbalize(condition))]"
                    + thenText
                    + directives.otherwiseTerminator
                    + otherwiseText
                    + directives.endIfTerminator
            case .forEach(let variable, let collection, let body):
                return "\(directives.forEachPrefix)\(variable)\(directives.loopInMarker)\(verbalize(collection))]"
                    + interpolationText(body, holeStyle: holeStyle)
                    + directives.endForTerminator
            case .formatted(let expression, let formatter):
                return hole(
                    "\(verbalize(expression))\(directives.formatAsMarker)\(formatter)",
                    style: holeStyle
                )
            }
        }.joined()
    }

    private func hole(_ content: String, style: InterpolationHoleStyle) -> String {
        switch style {
        case .template:
            return surface.templateHoleOpen + content + surface.templateHoleClose
        case .shell:
            return surface.shellHoleOpen + content + surface.shellHoleClose
        }
    }
}
