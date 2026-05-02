import Testing
import Foundation
@testable import MeridianCore

@Suite("Phase 7 Forcing Function — babysit.meridian")
struct Phase7BabysitForcingFunction {

    // MARK: - Source loaders

    private func examplesURL() -> URL {
        var url = URL(fileURLWithPath: #file)
        while url.lastPathComponent != "meridian" {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.appendingPathComponent("examples")
    }

    private func loadFixturePair() throws -> (meridian: String, merconfig: String) {
        let dir = examplesURL()
        let mer = try String(contentsOf: dir.appendingPathComponent("babysit.meridian"),   encoding: .utf8)
        let cfg = try String(contentsOf: dir.appendingPathComponent("github.merconfig"),   encoding: .utf8)
        return (mer, cfg)
    }

    private func compiledSource() throws -> String {
        let (mer, cfg) = try loadFixturePair()
        return try Compiler(options: .init()).compile(
            meridianSource: mer,
            meridianFile: "babysit.meridian",
            merconfigSource: cfg,
            merconfigFile: "github.merconfig"
        )
    }

    // MARK: - Tests

    @Test("babysit.meridian compiles without error")
    func compilesSuccessfully() throws {
        _ = try compiledSource()
    }

    @Test("generated Swift has skillMetadata static")
    func hasSkillMetadata() throws {
        let out = try compiledSource()
        #expect(out.contains("skillMetadata"),
                Comment(rawValue: "Expected skillMetadata in:\n\(String(out.prefix(2000)))"))
    }

    @Test("generated Swift has until loop (repeat-while or while)")
    func hasUntilLoop() throws {
        let out = try compiledSource()
        #expect(out.contains("repeat") || out.contains("while"),
                Comment(rawValue: "Expected loop construct in:\n\(String(out.prefix(2000)))"))
    }

    @Test("generated Swift has runtime discretion call")
    func hasDecideCall() throws {
        let out = try compiledSource()
        #expect(out.contains("runtime.discretion.decide"),
                Comment(rawValue: "Expected runtime.discretion.decide in:\n\(String(out.prefix(2000)))"))
    }

    @Test("generated Swift has plan-mode prose call")
    func hasProsePlanCall() throws {
        let out = try compiledSource()
        #expect(out.contains("runtime.executeProsePlan"),
                Comment(rawValue: "Expected runtime.executeProsePlan in:\n\(String(out.prefix(3000)))"))
    }

    @Test("generated Swift has zero _unresolved placeholders")
    func noUnresolved() throws {
        let out = try compiledSource()
        let count = out.components(separatedBy: "_unresolved").count - 1
        #expect(count == 0,
                Comment(rawValue: "Found \(count) _unresolved in:\n\(out)"))
    }

    @Test("babysit workflow struct is generated")
    func hasBabysitStruct() throws {
        let out = try compiledSource()
        #expect(out.contains("Babysit"),
                Comment(rawValue: "Expected Babysit struct in:\n\(String(out.prefix(2000)))"))
    }
}
