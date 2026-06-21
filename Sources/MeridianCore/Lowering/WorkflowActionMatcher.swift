/// Shared stem-overlap mechanics for "does this rule/convention action refer to
/// this workflow?" matching. The tokenize→stems→intersection-count machinery is
/// identical across `ConventionInjector` and `RuleInjector`; only the workflow
/// token scope and the acceptance threshold differ (and those stay at the call
/// sites — they are behavior-sensitive and intentionally distinct).
enum WorkflowActionMatcher {

    enum Scope {
        /// Workflow name tokens only (permission-verb matching).
        case nameOnly
        /// Workflow name + every parameter-kind token (convention matching).
        case nameAndParameters
    }

    /// Count of action stems that also appear in the workflow's token set. Zero
    /// when the action has no content stems.
    static func actionStemOverlap(action: String, workflow: IRWorkflow, scope: Scope, lexicon: EnglishLexicon) -> Int {
        let stopwords = lexicon.toolStopwords.union(lexicon.articles).union(lexicon.prepositions)
        func stemSet(_ s: String) -> Set<String> {
            Set(WordStemmer.tokenize(s, stopwords: stopwords).flatMap(WordStemmer.stems))
        }
        let actionStems = stemSet(action)
        guard !actionStems.isEmpty else { return 0 }
        var workflowStems = stemSet(workflow.name)
        if scope == .nameAndParameters {
            for p in workflow.parameters {
                workflowStems.formUnion(stemSet(p.kind.name))
            }
        }
        return actionStems.intersection(workflowStems).count
    }
}
