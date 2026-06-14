import Testing
import Foundation
import MeridianRuntime
import MeridianTools

/// Batch 4 (Tools slice): the pure built-in sub-branches not already exercised
/// — absent regex capture group (NSNotFound), json.transform with no value /
/// path miss, validate with a non-string `required` entry, time.format with an
/// explicit timezone, and the `registerBuiltins` closure-dispatch arms (the
/// llm.* branch and the default branch). The http/shell/mcp dispatch paths are
/// integration boundaries (bucket A) and stay floored.

@Suite("Reachable coverage — batch 4 (MeridianTools)")
struct ReachableCoverageToolsTests {

    @Test("regex.match emits .null for an absent optional capture group")
    func regexAbsentGroup() async throws {
        let r = try await MeridianTools.invoke("regex.match", args: [
            "pattern": .string("a(b)?c"),
            "text": .string("ac"),     // optional group (b) does not participate → NSNotFound
        ])
        guard case .record(let dict) = r, case .list(let matches)? = dict["matches"],
              case .record(let m0)? = matches.first, case .list(let groups)? = m0["groups"]
        else { Issue.record("shape"); return }
        #expect(groups.contains(.null))   // the absent group
    }

    @Test("json.transform: missing value arg and a path miss both yield .null")
    func transformEdges() async throws {
        #expect(try await MeridianTools.invoke("json.transform", args: ["path": .string("a.b")]) == .null)
        let miss = try await MeridianTools.invoke("json.transform", args: [
            "value": .record(["a": .number(1)]), "path": .string("a.b")])  // .number isn't a record
        #expect(miss == .null)
    }

    @Test("validate.json_schema ignores non-string required entries and reports missing")
    func validateRequired() async throws {
        let r = try await MeridianTools.invoke("validate.json_schema", args: [
            "schema": .record(["required": .list([.string("name"), .number(7)])]),  // .number(7) dropped
            "value": .record(["other": .string("x")]),
        ])
        guard case .record(let dict) = r else { Issue.record("shape"); return }
        #expect(dict["valid"] == .boolean(false))
    }

    @Test("time.format honours an explicit timezone + custom format")
    func timeFormatTimezone() async throws {
        let r = try await MeridianTools.invoke("time.format", args: [
            "value": .dateTime(Date(timeIntervalSince1970: 0)),
            "format": .string("yyyy-MM-dd"),
            "timezone": .string("UTC"),
            "locale": .string("en_US_POSIX"),
        ])
        #expect(r == .string("1970-01-01"))
    }

    @Test("registerBuiltins wires the llm.* and default closure-dispatch arms")
    func registerBuiltinsClosures() async throws {
        let reg = ToolRegistry()
        await reg.registerBuiltins()
        // default arm → uuid.generate produces a non-empty string
        let u = try await reg.dispatch(tool: "uuid.generate", args: [:])
        guard case .string(let s) = u else { Issue.record("uuid"); return }
        #expect(!s.isEmpty)
        // llm.* arm → llm.decide returns the deterministic boolean stub
        let d = try await reg.dispatch(tool: "llm.decide", args: [:])
        #expect(d == .boolean(false))
    }
}
