import Foundation
import MeridianRuntime

// MARK: - ConventionInjector
//
// Maps the rulebook's Inform-style behavioral conventions (`[RulebookRule]`,
// produced by `InformRulebookParser`) onto lowered `[IRWorkflow]`. This is the
// cross-cutting half of the rulebook engine: gbrain guarantees like Iron-Law
// back-linking, the notability gate, and brain-first are declared ONCE in
// `brain.merrules` and injected into every matching workflow, instead of being
// restated per skill.
//
// It complements `RuleInjector` (which operates on `ParsedRule`, a different
// type): the injection patterns — prepend a guard, append a step — are the
// same, but the rule source and matching differ, so this is its own path.
//
// Determinism contract: a convention's `body` is parsed + lowered through the
// SAME strict pipeline as hand-authored source (via the injected
// `lowerBody` closure). A convention can never reach the LLM, widen tool scope,
// or bypass strict mode — its body must resolve like any other statement.
//
// Phase → placement:
//   • before / check        → prepend (a precondition guard before the action)
//   • after / report / carry-out → append (a step after the action)
//   • instead of            → replace the workflow body
struct ConventionInjector {
    let lexicon: EnglishLexicon
    let trace: ParserTrace
    /// Parse + lower a convention body statement to IR. Injected by `ASTToIR`
    /// to avoid a parser/lowerer cycle; runs the full strict pipeline so an
    /// unresolved body is a hard error exactly like inline source.
    let lowerBody: (String, Int) throws -> [IRPrimitive]

    func inject(conventions: [RulebookRule], into workflows: [IRWorkflow]) throws -> [IRWorkflow] {
        guard !conventions.isEmpty else { return workflows }
        var result = workflows
        for convention in conventions {
            for idx in result.indices where actionMatches(convention.action, workflow: result[idx]) {
                let lowered = try lowerBody(convention.body, convention.sourceLine)
                guard !lowered.isEmpty else { continue }
                result[idx] = applyPhase(convention.phase, primitives: lowered, to: result[idx])
                trace.log(.lowering, "convention @L\(convention.sourceLine) [\(convention.phase)] → \(result[idx].name)")
            }
        }
        return result
    }

    // MARK: - Placement

    private func applyPhase(_ phase: RulebookPhase, primitives: [IRPrimitive], to wf: IRWorkflow) -> IRWorkflow {
        var statements = wf.body.statements
        switch phase {
        case .before, .check:
            statements = primitives + statements
        case .after, .report, .carryOut:
            statements = statements + primitives
        case .instead:
            statements = primitives
        }
        return rebuild(wf, statements: statements)
    }

    private func rebuild(_ wf: IRWorkflow, statements: [IRPrimitive]) -> IRWorkflow {
        IRWorkflow(
            name: wf.name,
            parameters: wf.parameters,
            body: IRBlock(statements: statements, sourceRange: wf.body.sourceRange),
            mode: wf.mode,
            sourceFile: wf.sourceFile,
            sourceRange: wf.sourceRange,
            explicitStructName: wf.explicitStructName,
            allowsDiscretion: wf.allowsDiscretion
        )
    }

    // MARK: - Matching

    /// A convention applies to a workflow when its action's content tokens
    /// overlap the workflow's name + parameter-kind tokens by at least two
    /// stems. The threshold of two avoids spurious matches on a single common
    /// noun (e.g. every workflow that mentions "page").
    private func actionMatches(_ action: String, workflow: IRWorkflow) -> Bool {
        let stopwords = lexicon.toolStopwords.union(lexicon.articles).union(lexicon.prepositions)
        let actionStems = Set(tokenize(action, stopwords: stopwords).flatMap(stems))
        guard !actionStems.isEmpty else { return false }
        var workflowStems = Set(tokenize(workflow.name, stopwords: stopwords).flatMap(stems))
        for p in workflow.parameters {
            workflowStems.formUnion(tokenize(p.kind.name, stopwords: stopwords).flatMap(stems))
        }
        return actionStems.intersection(workflowStems).count >= 2
    }

    private func tokenize(_ s: String, stopwords: Set<String>) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
    }

    private func stems(of word: String) -> [String] {
        var out: [String] = [word]
        let lower = word.lowercased()
        if lower.hasSuffix("ies") && lower.count > 4 {
            out.append(String(lower.dropLast(3)) + "y")
        } else if lower.hasSuffix("es") && lower.count > 3 {
            out.append(String(lower.dropLast(2)))
        } else if lower.hasSuffix("s") && lower.count > 2 {
            out.append(String(lower.dropLast()))
        }
        if lower.hasSuffix("ed") && lower.count > 3 {
            out.append(String(lower.dropLast(2)))
            out.append(String(lower.dropLast()))
        }
        if lower.hasSuffix("ing") && lower.count > 4 {
            out.append(String(lower.dropLast(3)))
            out.append(String(lower.dropLast(3)) + "e")
        }
        return out
    }
}
