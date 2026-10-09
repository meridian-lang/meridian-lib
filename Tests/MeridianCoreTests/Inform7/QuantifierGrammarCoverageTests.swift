import Foundation
import Testing
@testable import MeridianCore

/// Direct branch coverage for `QuantifierGrammar`'s `whose`-clause trailing-
/// body split logic (`splitWhoseTrailingBody` and its two helpers), which the
/// full compile corpus only exercises through its "happy path" shapes.
@Suite("QuantifierGrammar whose-trailing-body branch coverage")
struct QuantifierGrammarCoverageTests {
    private func parse(_ s: String) -> ExpressionAST? {
        ExpressionParser().parse(s)
    }

    /// `QuantifierGrammar` constructed directly, bypassing
    /// `ExpressionParser`'s own top-level ` and `/` or ` splitting — that
    /// outer splitting means a *full-sentence* `... whose X and Y` never
    /// actually reaches `QuantifierGrammar.parse` with the `and` still
    /// embedded in its text (the outer parser peels `Y` off as a second
    /// top-level conjunct first). The connector-detection guard inside
    /// `splitWhoseTrailingBody` is real, load-bearing logic for whatever
    /// upstream shape *does* hand it a whose-clause with an embedded
    /// connector intact (e.g. a nested nominal restriction) — so it is
    /// exercised here via direct construction instead.
    private func quantifierGrammar() -> QuantifierGrammar {
        let ep = ExpressionParser()
        let description = DescriptionGrammar(lexicon: .default, symbols: nil, atom: { .malformed($0) }, recurse: ep.parse)
        return QuantifierGrammar(lexicon: .default, description: description, recurse: ep.parse)
    }

    @Test("a whose-clause with a boolean connector is a compound predicate, never a trailing body")
    func compoundWhoseClauseIsNeverSplit() {
        let result = quantifierGrammar().parse("no pages whose status is \"draft\" and priority is \"high\"")
        guard case .quantified(let q) = result else {
            Issue.record("expected quantified expression, got \(String(describing: result))")
            return
        }
        #expect(q.description.wherePredicate != nil)
        #expect(q.body == nil)
    }

    @Test("a single-occurrence whose-clause with no trailing body stays a bare where-predicate")
    func singleOccurrenceWhoseClauseHasNoTrailingBody() {
        guard case .quantified(let q) = parse("no pages whose status is \"draft\"") else {
            Issue.record("expected quantified expression")
            return
        }
        #expect(q.description.wherePredicate != nil)
        #expect(q.body == nil)
    }

    @Test("two occurrences of the same copular verb split at the second into a trailing body")
    func repeatedCopulaSplitsIntoTrailingBody() {
        guard case .quantified(let q) = parse("at least 1 alert whose status is active is fresh") else {
            Issue.record("expected quantified expression")
            return
        }
        #expect(q.description.wherePredicate != nil)
        #expect(q.body != nil)
    }

    @Test("an unterminated quoted value in a whose-clause falls through to the fallback split")
    func unterminatedQuoteFallsThroughToFallback() {
        // A dangling opening quote (never closed) must not crash
        // `splitAfterQuotedValue`; it should fall through to the occurrence-
        // count fallback (or return no split at all) rather than matching.
        let result = parse("no pages whose status is \"draft and something else is fresh")
        guard case .quantified = result else {
            Issue.record("expected quantified expression, got \(String(describing: result))")
            return
        }
    }

    @Test("a possessive-pronoun keyed reference with nothing trailing it stays a bare where-predicate")
    func keyedReferenceWithNoTrailingBodyHasNoSplit() {
        guard case .quantified(let q) = parse("no alerts whose service name is its name") else {
            Issue.record("expected quantified expression")
            return
        }
        #expect(q.description.wherePredicate != nil)
        #expect(q.body == nil)
    }

    @Test("a possessive-pronoun keyed reference followed by a non-verb tail stays a bare where-predicate")
    func keyedReferenceWithNonVerbTailHasNoSplit() {
        // No boolean connector present (so the earlier connector guard does
        // not short-circuit first) and the text after the keyed reference's
        // property word ("today") is not a `quantifierBodyVerbs` marker, so
        // `splitAfterKeyedReference` must reject the split and fall through.
        let result = quantifierGrammar().parse("no alerts whose service name is its name today")
        guard case .quantified(let q) = result else {
            Issue.record("expected quantified expression, got \(String(describing: result))")
            return
        }
        #expect(q.description.wherePredicate != nil)
        #expect(q.body == nil)
    }

    @Test("a possessive-pronoun keyed reference followed by a copular verb splits into a trailing body")
    func keyedReferenceWithVerbTailSplitsIntoTrailingBody() {
        guard case .quantified(let q) = parse("at least 1 critical alert whose service name is its name is fresh") else {
            Issue.record("expected quantified expression")
            return
        }
        #expect(q.description.wherePredicate != nil)
        #expect(q.body != nil)
    }

    @Test("a quantifier body consisting solely of a bare verb (no complement) normalizes to itself")
    func bareVerbOnlyBodyNormalizesToItself() {
        // `earliestBodyVerbSplit` can hand `normalizeQuantBody` a body that is
        // just the verb itself with no trailing predicate.
        let result = parse("any tasks are")
        guard case .quantified = result else {
            Issue.record("expected quantified expression, got \(String(describing: result))")
            return
        }
    }
}
