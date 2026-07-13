import Foundation
import Testing
@testable import MeridianCore

@Suite("Wave 7 verbalizer round trip")
struct VerbalizerRoundTripTests {
    @Test("SEM-8-03 sample-gbrain and corpora compile verbalize compile structurally")
    func sem803CorpusRoundTrip() throws {
        let fixtures = try VerbalizerTestSupport.sampleGbrainFixtures() + VerbalizerTestSupport.corpusFixtures()
        #expect(fixtures.count >= 100, Comment(rawValue: "Expected sample-gbrain plus corpus fixtures, found \(fixtures.count)"))

        var failures: [String] = []
        for fixture in fixtures {
            do {
                try assertRoundTrip(fixture)
            } catch {
                failures.append("\(fixture.displayPath): \(error)")
            }
        }

        #expect(failures.isEmpty, Comment(rawValue: "Verbalizer round-trip failures:\n" + failures.joined(separator: "\n\n")))
    }

    @Test("canonical verbalization reaches a byte-identical fixpoint across all corpora")
    func canonicalFixpointForAllCorpusFiles() throws {
        let fixtures = try VerbalizerTestSupport.sampleGbrainFixtures() + VerbalizerTestSupport.corpusFixtures()
        #expect(fixtures.count >= 100, Comment(rawValue: "Expected sample-gbrain plus corpus fixtures, found \(fixtures.count)"))
        var failures: [String] = []
        for fixture in fixtures {
            do {
                let source = try String(contentsOf: fixture.file, encoding: .utf8)
                let (_, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
                let reparsedCanonical = try Verbalizer(model: second).verbalize()
                if reparsedCanonical != canonical {
                    failures.append("""
                    \(fixture.displayPath): canonical was not a fixpoint
                    first:
                    \(VerbalizerTestSupport.snippet(canonical, limit: 500))
                    second:
                    \(VerbalizerTestSupport.snippet(reparsedCanonical, limit: 500))
                    """)
                }
            } catch {
                failures.append("\(fixture.displayPath): \(error)")
            }
        }

        #expect(failures.isEmpty, Comment(rawValue: "Verbalizer fixpoint failures:\n" + failures.joined(separator: "\n\n")))
    }

    private func assertRoundTrip(_ fixture: VerbalizerTestSupport.Fixture) throws {
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)

        VerbalizerTestSupport.assertNoUnresolved(first, context: fixture.displayPath)
        VerbalizerTestSupport.assertNoUnresolved(second, context: "\(fixture.displayPath) canonical")

        guard IREquality.structurallyEqual(first.workflows, second.workflows) else {
            throw RoundTripFailure(
                message: """
                workflows differ: \(VerbalizerTestSupport.firstInequalityHint(first.workflows, second.workflows))
                canonical snippet:
                \(VerbalizerTestSupport.snippet(canonical))
                """
            )
        }
        guard VerbalizerTestSupport.definitionInfosEqual(first.loweredDefinitions, second.loweredDefinitions) else {
            throw RoundTripFailure(
                message: """
                lowered definitions differ
                canonical snippet:
                \(VerbalizerTestSupport.snippet(canonical))
                """
            )
        }
    }

    private struct RoundTripFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }
}
