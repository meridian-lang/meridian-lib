import Foundation
import MeridianRuntime

public struct Verbalizer: Sendable {
    public let model: VerbalizerModel
    let invokeInverter: InvokeInverter

    public init(model: VerbalizerModel) {
        self.model = model
        self.invokeInverter = InvokeInverter(symbols: model.symbols)
    }

    var grammar: FixedGrammar { model.lexicon.grammar }
    var surface: FixedVerbalizerSurface { grammar.verbalizer }
    var statement: FixedStatementKeywords { grammar.statement }

    public func verbalize(annotateNormIDs: Bool = false) throws -> String {
        let trace = ParserTrace.current
        try validateCanonicalLexiconMarkers()
        try IRValidator.validate(model.workflows, sourceFile: model.sourceFileName)
        trace.log(.verbalizer, "verbalizing \(model.workflows.count) workflow(s)")
        let emitWorkflows = model.workflows.filter(shouldEmitWorkflow)
        let omitEntryKeys = emitWorkflows.contains { isImplicitEntryWorkflow($0) }
        var chunks: [String] = []
        if let frontmatter = verbalizeFrontmatter(omitImplicitEntryKeys: omitEntryKeys) {
            chunks.append(frontmatter)
        }
        let inlineDefinitions = model.loweredDefinitions.filter(\.isInline)
        if !inlineDefinitions.isEmpty {
            chunks.append(inlineDefinitions.map(verbalizeDefinition).joined(separator: "\n"))
        }
        chunks.append(contentsOf: emitWorkflows.map {
            verbalizeWorkflow($0, annotateNormIDs: annotateNormIDs)
        })
        let norms = collectedNorms()
        if !norms.isEmpty {
            chunks.append(norms.map { verbalize($0, annotateNormID: annotateNormIDs) }.joined(separator: "\n"))
        }
        return chunks.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    public func verbalize(_ norm: NormIR, annotateNormID: Bool = false) -> String {
        let authored = norm.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !authored.isEmpty {
            let base = CanonicalForms.sentence(authored)
            return base + normAnnotation(norm.id, enabled: annotateNormID)
        }
        let markers = model.lexicon.grammar.ruleMarkers
        let head = normScopeSubject(norm.scope)
        let body: String
        switch norm.kind {
        case .prohibition:
            body = head + markers.mustNotMarker + invokeActionPattern(norm.actionPattern) + normBlockingSuffix(norm, markers: markers)
        case .obligation:
            let condition = norm.condition.map { verbalize($0) } ?? ""
            body = condition + markers.mustHoldMarker + normBlockingSuffix(norm, markers: markers)
        case .permission:
            body = head + markers.mayMarker + invokeActionPattern(norm.actionPattern)
        }
        return CanonicalForms.sentence(body) + normAnnotation(norm.id, enabled: annotateNormID)
    }

    public func verbalize(_ assertion: AssertIR, annotateNormID: Bool = false) -> String {
        verbalizeAssert(assertion, annotateNormID: annotateNormID)
    }

    private func collectedNorms() -> [NormIR] {
        var byID: [String: NormIR] = [:]
        for workflow in model.workflows {
            for norm in workflow.norms {
                byID[norm.id] = norm
            }
        }
        return byID.values.sorted {
            if $0.sourceRange.startLine != $1.sourceRange.startLine {
                return $0.sourceRange.startLine < $1.sourceRange.startLine
            }
            return $0.id < $1.id
        }
    }

    private func normAnnotation(_ id: String?, enabled: Bool) -> String {
        guard enabled, let id, !id.isEmpty else { return "" }
        return " [\(id)]"
    }

    private func normScopeSubject(_ scope: NormScope) -> String {
        switch scope {
        case .skill:
            return ""
        case .workflow(let name):
            return "within \(CanonicalForms.words(fromIdentifier: name))"
        case .section(let stablePath):
            return "within \(CanonicalForms.words(fromIdentifier: stablePath))"
        case .kind(let name):
            let words = CanonicalForms.words(fromIdentifier: name)
            return model.lexicon.indefiniteArticlePrefix(for: words) + words
        }
    }

    private func normBlockingSuffix(_ norm: NormIR, markers: FixedRuleMarkers) -> String {
        norm.blocking ? markers.blockingCommaSuffix : ""
    }

    private func invokeActionPattern(_ pattern: ActionPatternIR?) -> String {
        guard let pattern else { return "" }
        let markers = model.lexicon.grammar.ruleMarkers
        let toolName = model.symbols.tools[pattern.toolID]?.methodName ?? pattern.toolID
        var text = markers.invokeActionHead + CanonicalForms.words(fromIdentifier: toolName)
        for constraint in pattern.argumentConstraints.sorted(by: { $0.path < $1.path }) {
            text += markers.whoseMarker
                + CanonicalForms.words(fromIdentifier: constraint.path)
                + " "
                + CanonicalForms.comparison(constraint.op, lexicon: model.lexicon)
                + " "
                + verbalize(constraint.value)
        }
        return text
    }

    private func comparisonOpSurface(_ op: ComparisonOp) -> String {
        CanonicalForms.comparison(op, lexicon: model.lexicon)
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


    public func verbalize(_ prim: IRPrimitive) -> String {
        verbalize(prim, annotateNormIDs: false)
    }

    private func verbalize(_ prim: IRPrimitive, annotateNormIDs: Bool) -> String {
        ParserTrace.current.log(.verbalizer, primitiveTraceLabel(prim))
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
            return verbalizeAssert(assertion, annotateNormID: annotateNormIDs)
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

    private func verbalizeWorkflow(_ workflow: IRWorkflow, annotateNormIDs: Bool = false) -> String {
        let trace = ParserTrace.current
        let span = trace.push(.verbalizer, "workflow \(workflow.structName)")
        defer { trace.pop(span) }
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
        let body = blockLines(workflow.body, annotateNormIDs: annotateNormIDs)
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

    private func isImplicitEntryWorkflow(_ workflow: IRWorkflow) -> Bool {
        guard let metadata = model.metadata,
              let name = metadata["name"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !name.isEmpty else { return false }
        let display = workflowFallbackName(workflow).lowercased()
        return display == name || display.hasPrefix(name + " ")
    }

    private func verbalizeFrontmatter(omitImplicitEntryKeys: Bool = false) -> String? {
        guard let metadata = model.metadata, !metadata.entries.isEmpty else { return nil }
        var lines = ["---"]
        var emittedTools = false
        for entry in metadata.entries {
            let value = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedKey = normalizeFrontmatterKey(entry.key)
            if omitImplicitEntryKeys, normalizedKey == "name" || normalizedKey == "parameters" {
                continue
            }
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
        // A deontic guard is *derived* from the rule that produced it, and the
        // canonical form prints that rule (with its norm id) separately.
        // Rendering the wrapper as well would make the canonical text carry the
        // guard twice, and recompiling it would nest a second guard around the
        // invoke. Print the guarded body only.
        if branch.deonticGuard != nil {
            return blockLines(branch.thenBlock).joined(separator: "\n")
        }
        switch branch.condition {
        case .predicate(let condition):
            if branch.authoredForm == .unlessSuffix,
               branch.thenBlock.statements.count == 1,
               let inner = unwrapNegatedBranchPredicate(condition) {
                var action = verbalize(branch.thenBlock.statements[0])
                if action.hasSuffix(".") { action = String(action.dropLast()) }
                let unlessMarker = grammar.suffixConditionalNegated.trimmingCharacters(in: .whitespaces)
                return CanonicalForms.sentence("\(action) \(unlessMarker) \(verbalize(inner))")
            }
            var header: String
            if branch.authoredForm == .unlessHeader,
               let inner = unwrapNegatedBranchPredicate(condition) {
                header = "\(statement.unlessPrefix)\(verbalize(inner))"
            } else if branch.authoredForm == .ifNot,
                      let inner = unwrapNegatedBranchPredicate(condition) {
                header = "\(statement.ifPrefix)\(grammar.booleanConnectors.notPrefix)\(verbalize(inner))"
            } else {
                header = "\(statement.ifPrefix)\(verbalize(condition))"
            }
            switch branch.unknownPolicy {
            case .asTrue:
                header += statement.treatingUnknownAsMarker + statement.unknownAsTrueKeyword
            case .asFalse:
                header += statement.treatingUnknownAsMarker + statement.unknownAsFalseKeyword
            case .explicit:
                break
            }
            var lines = ["\(header),"]
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

    private func unwrapNegatedBranchPredicate(_ expression: IRExpression) -> IRExpression? {
        guard case .logical(.not, let operands) = expression, operands.count == 1 else { return nil }
        return operands[0]
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

    func sortByMarker() -> String {
        model.lexicon.sortByMarkers.first ?? surface.sortByMarker
    }

    private func verbalizeAssert(_ assertion: AssertIR, annotateNormID: Bool = false) -> String {
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
            return CanonicalForms.sentence(surface.assertPrefix + assertSurface) + normAnnotation(assertion.normID, enabled: annotateNormID)
        }
        if let otherwise = assertion.otherwiseAction {
            // Authored/parser surface is `assert X otherwise:` (colon), not the
            // branch form `otherwise,`. Same FixedGrammar label as match default.
            let otherwiseLabel = statement.matchOtherwiseLabel
            var lines = [surface.assertPrefix + assertSurface + " \(otherwiseLabel)"]
            lines += CanonicalForms.indented(blockLines(otherwise))
            return lines.joined(separator: "\n") + normAnnotation(assertion.normID, enabled: annotateNormID)
        }
        return CanonicalForms.sentence(surface.assertPrefix + assertSurface) + normAnnotation(assertion.normID, enabled: annotateNormID)
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

    private func primitiveTraceLabel(_ prim: IRPrimitive) -> String {
        switch prim {
        case .invoke: return "primitive invoke"
        case .bind: return "primitive bind"
        case .branch: return "primitive branch"
        case .iterate: return "primitive iterate"
        case .assert: return "primitive assert"
        case .emit: return "primitive emit"
        case .wait: return "primitive wait"
        case .commit: return "primitive commit"
        case .recover: return "primitive recover"
        case .simultaneously: return "primitive simultaneously"
        case .aiJudgment: return "primitive aiJudgment"
        case .aiAutonomy: return "primitive aiAutonomy"
        case .complete: return "primitive complete"
        }
    }

    private func blockLines(_ block: IRBlock, annotateNormIDs: Bool = false) -> [String] {
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
            lines += verbalize(primitive, annotateNormIDs: annotateNormIDs).components(separatedBy: "\n")
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

}
