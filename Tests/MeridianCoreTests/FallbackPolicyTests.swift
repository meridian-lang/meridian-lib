import Testing
@testable import MeridianCore

@Suite("FallbackPolicy — parse / merge / allows")
struct FallbackPolicyTests {
    @Test("strict allows nothing; lenient allows every kind")
    func presets() {
        for k in FallbackKind.allCases {
            #expect(!FallbackPolicy.strict.allows(k))
            #expect(FallbackPolicy.lenient.allows(k))
        }
    }

    @Test("parse picks up each named kind and reports unknown tokens")
    func parseNamed() {
        let (policy, unknown) = FallbackPolicy.parse("unresolved-phrases, unattached-rules, bogus")
        #expect(policy.allows(.unresolvedPhrases))
        #expect(policy.allows(.unattachedRules))
        #expect(!policy.allows(.unknownTools))
        #expect(unknown == ["bogus"])
    }

    @Test("all / * / lenient each enable everything")
    func wildcards() {
        for spelling in ["all", "*", "lenient"] {
            let (policy, unknown) = FallbackPolicy.parse(spelling)
            #expect(unknown.isEmpty)
            for k in FallbackKind.allCases { #expect(policy.allows(k)) }
        }
    }

    @Test("empty and whitespace-only tokens are ignored")
    func emptyTokens() {
        let (policy, unknown) = FallbackPolicy.parse(" , ,unknown-tools, ")
        #expect(policy.allows(.unknownTools))
        #expect(unknown.isEmpty)
        #expect(policy.allowed.count == 1)
    }

    @Test("merging unions the allowed sets")
    func merge() {
        let a = FallbackPolicy(allowed: [.unresolvedPhrases])
        let b = FallbackPolicy(allowed: [.unknownTools])
        let m = a.merging(b)
        #expect(m.allows(.unresolvedPhrases))
        #expect(m.allows(.unknownTools))
        #expect(!m.allows(.unparseableRules))
    }

    @Test("every FallbackKind has a stable raw value")
    func rawValues() {
        #expect(FallbackKind.unresolvedPhrases.rawValue == "unresolved-phrases")
        #expect(FallbackKind.unparseableRules.rawValue == "unparseable-rules")
        #expect(FallbackKind.unattachedRules.rawValue == "unattached-rules")
        #expect(FallbackKind.unresolvedTriggerActions.rawValue == "unresolved-trigger-actions")
        #expect(FallbackKind.unknownTools.rawValue == "unknown-tools")
        #expect(FallbackKind.allCases.count == 5)
    }
}
