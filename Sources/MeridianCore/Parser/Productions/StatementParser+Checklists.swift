import Foundation
import MeridianRuntime

// MARK: - Checklist sentinels and parse-block helpers
//
// Task-list checklist expansion, anaphora referent tracking, and
// recover-attachment when appending statements to a block —
// extracted from StatementParser for Phase 3 readability.

extension StatementParser {

    /// Desugar a task-list checklist item to an invariant assert. A checkable
    /// item becomes `make sure <cond>`; a non-checkable one is a hard error
    /// (rephrase to a comparison or move under an `(( inert ))` section).
    func checklistInvariant(_ line: SourceLine, sourceFile: String) throws -> StatementAST {
        let classifier = ConditionClassifier(symbols: symbols, lexicon: lexicon)
        // Shared with Contract invariants: `every emitted <noun> <predicate>`
        // is an assert on the bound result `<noun>`.
        let text = classifier.normalizeFormatInvariant(line.statement)
        switch classifier.classify(text) {
        case .checkable:
            return .assertStmt(AssertStatementAST(
                condition: exprParser.parse(text),
                message: "Expected \(text)",
                sourceLine: line.number
            ))
        case .dispatchPhrase, .fuzzy:
            try raiseStructural(
                .uncheckablePredicate,
                message: "checklist item \"\(text)\" is not a structurally checkable predicate. Rephrase it as a comparison (e.g. `- [ ] the link count is at least 1`), route the whole list to the planner with a `!!! checklist (( ai-autonomy ))` marker above it, or move it under an `(( inert ))` section to keep it as documentation.",
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
                help: "Rephrase as a comparison, add `!!! checklist (( ai-autonomy ))` above the list, or mark the section `(( inert ))`.")
        }
    }

    /// Expand a `!!! checklist (( … ))` sentinel into statements per its mode:
    ///   • invariant   → one `assert` per item (each must be checkable).
    ///   • inert       → nothing (documentation).
    ///   • aiAutonomy  → one autonomy prose step: loop until every criterion holds.
    ///   • aiDiscretion → one discretion prose step: verify/resolve the criteria.
    /// Returns nil when `line` is not a checklist sentinel.
    func checklistStatements(_ line: SourceLine, sourceFile: String) throws -> [StatementAST]? {
        guard let (mode, body) = decodeChecklistSentinel(line.text) else { return nil }
        let items = body.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        switch mode {
        case .inert:
            return []
        case .invariant:
            return try items.map { item in
                let itemLine = SourceLine(indent: line.indent, text: item, raw: line.raw, number: line.number)
                return try checklistInvariant(itemLine, sourceFile: sourceFile)
            }
        case .aiAutonomy:
            return [proseStep(checklistProse(items, autonomy: true), dispatch: .autonomy, line: line)]
        case .aiDiscretion:
            return [proseStep(checklistProse(items, autonomy: false), dispatch: .discretion, line: line)]
        }
    }

    /// Render a fuzzy acceptance checklist as planner instructions. The criteria
    /// are embedded verbatim so the planner has them as the goal context.
    func checklistProse(_ items: [String], autonomy: Bool) -> String {
        let header = autonomy
            ? "Ensure every acceptance criterion below holds, taking corrective action until all of them are satisfied:"
            : "Verify the following acceptance criteria and resolve any that are not met:"
        return header + "\n" + items.map { "- \($0)" }.joined(separator: "\n")
    }

    /// Wrap synthesized planner prose in a `.proseStep` statement with an
    /// explicit dispatch — the same path `use judgment to …:` takes, so it is
    /// valid in any workflow and runs through the planner/scope/checkpoint code.
    func proseStep(_ text: String, dispatch: ProseDispatchAST, line: SourceLine) -> StatementAST {
        .proseStep(ProseStepAST(text: text, sourceLine: line.number, dispatch: dispatch))
    }

    func shouldResolveAnaphora(_ line: SourceLine) -> Bool {
        let lower = line.statement.lowercased()
        if lower.contains(lexicon.grammar.tryIdiomFailureSeparator) { return false }
        return true
    }

    func recordReferents(from statement: StatementAST, into referents: inout [String]) {
        switch statement {
        case .bind(let s):
            referents.append(camelize(s.name))
        case .rebind(let s):
            referents.append(camelize(s.name))
        case .note(let s):
            referents.append(camelize(s.binding))
        case .iteration(let s):
            if case .forEach(let variable, _) = s.mode { referents.append(variable) }
        case .labelled(let s):
            recordReferents(from: s.statement, into: &referents)
        default:
            break
        }
        if referents.count > 4 {
            referents = Array(referents.suffix(4))
        }
    }

    static let recoverPlaceholderWords = "__recover_placeholder__"

    func recoverPlaceholder(sourceLine: Int) -> StatementAST {
        .phraseInvocation(PhraseInvocationAST(
            words: Self.recoverPlaceholderWords,
            sourceLine: sourceLine
        ))
    }

    func appendStatement(_ statement: StatementAST, to stmts: inout [StatementAST]) {
        // `recover from …:` attaches to the immediately preceding statement.
        // When we see one, pop the predecessor from `stmts` and embed it.
        if case .recover(var rec) = statement,
           case .phraseInvocation(let placeholder) = rec.attached,
           (placeholder.words.isEmpty || placeholder.words == Self.recoverPlaceholderWords),
           let preceding = stmts.last {
            stmts.removeLast()
            rec = RecoverStatementAST(
                pattern: rec.pattern,
                handler: rec.handler,
                attached: preceding,
                sourceLine: rec.sourceLine
            )
            stmts.append(.recover(rec))
        } else {
            stmts.append(statement)
        }
    }
}
