import Foundation

/// One author-extensible `=== language ===` synonym category.
///
/// This is the single enumeration of the surface-vocabulary categories a
/// `.merconfig` may extend. Everything else about a category — the header
/// spellings that select it, the shape of its lines, and how its entries merge
/// into `EnglishLexicon` — is one row in `LexiconRegistry`, so adding a
/// category is a case here plus a registry row.
public enum LexiconCategory: String, CaseIterable, Sendable, Hashable {
    case comparison, duration, assertion, normativeCue, inferenceCue, referenceHeading,
         conditionVagueHedge, effectfulJudgment, article, parameterArticle, preposition,
         copula, participle, toolStopword, irregularPlural, contractReference,
         empty, filled, pastWindow, futureWindow, timestampAlias,
         aggregate, superlative, gradableAdjective, sortBy, ascending, descending,
         possessive, anaphora, conditionHeader, actionHeader, wildcard,
         traceOutcome, traceAuxiliary, shellFence, fenceTool,
         guardedFenceIntroducer, fallbackChainIntroducer, approvalTool
}

/// A single parsed `=== language ===` line, in the shape its category declares.
public enum LexiconEntry: Sendable, Hashable {
    /// A bare marker in a list category (`Assertion synonyms:` → `verify`).
    case phrase(String)
    /// `key = <comparison spelling>` (`exceeds = is more than`).
    case comparison(String, ComparisonOpAST)
    /// `key = <duration unit>` (`fortnight = week`).
    case duration(String, TimeUnitAST)
    /// `key = count` / `key = list`.
    case aggregate(String, AggregateKindAST)
    /// `key = <SuperlativeDirection raw value>` (`freshest = newest`).
    case superlative(String, SuperlativeDirection)
    /// `key = <property> <direction>` (`fresh = updatedAt ascending`).
    case gradable(String, GradableAdjectiveMetadata)
    /// `key = value` pairs — irregular plurals, trace outcomes, fence tools.
    case mapping(String, String)

    /// The surface string this entry is keyed by: its bare marker, or the
    /// left-hand side of a `key = value` line.
    public var phrase: String {
        switch self {
        case .phrase(let marker):                    return marker
        case .comparison(let key, _):                return key
        case .duration(let key, _):                  return key
        case .aggregate(let key, _):                 return key
        case .superlative(let key, _):               return key
        case .gradable(let key, _):                  return key
        case .mapping(let key, _):                   return key
        }
    }
}

/// Language-surface synonyms loaded from a `=== language ===` section in a
/// .merconfig file. Merged into the effective `EnglishLexicon` at compile time.
public struct LanguageSynonyms: Sendable {
    /// One entry list per category the section declared; an absent category
    /// declared nothing. Category semantics live in `LexiconRegistry`.
    public var entries: [LexiconCategory: [LexiconEntry]]
    /// `timestamp = <property>` — a scalar, not a list category; `nil` keeps
    /// the lexicon default.
    public var timestampProperty: String?

    public init(
        entries: [LexiconCategory: [LexiconEntry]] = [:],
        timestampProperty: String? = nil
    ) {
        self.entries = entries
        self.timestampProperty = timestampProperty
    }
}
