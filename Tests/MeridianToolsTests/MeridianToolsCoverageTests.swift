import Testing
import Foundation
@testable import MeridianTools
import MeridianRuntime

@Suite("MeridianTools.invoke — every local dispatch and helper")
struct MeridianToolsCoverageTests {

    @Test("json.parse covers string/number/bool/record/list/null")
    func jsonParse() async throws {
        let v = try await MeridianTools.invoke("json.parse",
            args: ["text": .string("{\"s\":\"x\",\"n\":3,\"b\":true,\"nil\":null,\"arr\":[1,2],\"obj\":{\"k\":1}}")])
        guard case .record(let r) = v else { Issue.record("expected record"); return }
        #expect(r["s"] == .string("x"))
        #expect(r["b"] == .boolean(true))
        #expect(r["nil"] == .null)
        if case .list(let a) = r["arr"] { #expect(a.count == 2) } else { Issue.record("arr") }
        if case .record = r["obj"] {} else { Issue.record("obj") }
    }

    @Test("json.stringify round-trips")
    func jsonStringify() async throws {
        let v = try await MeridianTools.invoke("json.stringify",
            args: ["value": .record(["a": .number(1), "b": .string("x")])])
        guard case .string(let s) = v else { Issue.record("expected string"); return }
        #expect(s.contains("\"a\""))
        #expect(s.contains("\"x\""))
    }

    @Test("json.transform navigates keys, indices, and misses")
    func jsonTransform() async throws {
        let value = Value.record(["items": .list([.record(["name": .string("first")]), .record(["name": .string("second")])])])
        let hit = try await MeridianTools.invoke("json.transform", args: ["value": value, "path": .string("items[1].name")])
        #expect(hit == .string("second"))
        let missKey = try await MeridianTools.invoke("json.transform", args: ["value": value, "path": .string("nope")])
        #expect(missKey == .null)
        let missIndex = try await MeridianTools.invoke("json.transform", args: ["value": value, "path": .string("items[9]")])
        #expect(missIndex == .null)
        let typeMismatch = try await MeridianTools.invoke("json.transform", args: ["value": .string("scalar"), "path": .string("x")])
        #expect(typeMismatch == .null)
    }

    @Test("regex.match captures groups and reports no-match")
    func regexMatch() async throws {
        let m = try await MeridianTools.invoke("regex.match",
            args: ["pattern": .string("(\\d+)-(\\d+)"), "text": .string("ab 12-34 cd")])
        guard case .record(let r) = m else { Issue.record("expected record"); return }
        #expect(r["matched"] == .boolean(true))
        let none = try await MeridianTools.invoke("regex.match",
            args: ["pattern": .string("zzz"), "text": .string("abc")])
        if case .record(let r2) = none { #expect(r2["matched"] == .boolean(false)) }
    }

    @Test("regex.replace substitutes")
    func regexReplace() async throws {
        let v = try await MeridianTools.invoke("regex.replace",
            args: ["pattern": .string("a"), "text": .string("banana"), "replacement": .string("o")])
        #expect(v == .string("bonono"))
    }

    @Test("validate.json_schema valid, missing, and non-record inputs")
    func validateSchema() async throws {
        let okSchema = Value.record(["required": .list([.string("name")])])
        let ok = try await MeridianTools.invoke("validate.json_schema",
            args: ["schema": okSchema, "value": .record(["name": .string("x")])])
        if case .record(let r) = ok { #expect(r["valid"] == .boolean(true)) }
        let missing = try await MeridianTools.invoke("validate.json_schema",
            args: ["schema": okSchema, "value": .record([:])])
        if case .record(let r) = missing { #expect(r["valid"] == .boolean(false)) }
        let bad = try await MeridianTools.invoke("validate.json_schema",
            args: ["schema": .string("nope"), "value": .string("nope")])
        if case .record(let r) = bad { #expect(r["valid"] == .boolean(false)) }
    }

    @Test("time.now / time.format with explicit format and ISO8601")
    func time() async throws {
        if case .dateTime = try await MeridianTools.invoke("time.now") {} else { Issue.record("expected dateTime") }
        let fixed = Date(timeIntervalSince1970: 0)
        let formatted = try await MeridianTools.invoke("time.format",
            args: ["value": .dateTime(fixed), "format": .string("yyyy"), "timezone": .string("UTC")])
        #expect(formatted == .string("1970"))
        // ISO8601 path (no explicit format) + .date input + timezone.
        if case .string(let iso) = try await MeridianTools.invoke("time.format",
            args: ["value": .date(fixed), "timezone": .string("UTC")]) {
            #expect(iso.contains("1970"))
        } else { Issue.record("iso") }
        // No value → uses Date(); no timezone → default.
        if case .string = try await MeridianTools.invoke("time.format", args: [:]) {} else { Issue.record("default time") }
    }

    @Test("uuid.generate, llm.decide/judge, and the unknown-tool default")
    func miscDispatch() async throws {
        if case .string(let u) = try await MeridianTools.invoke("uuid.generate") { #expect(u.count > 10) }
        #expect(try await MeridianTools.invoke("llm.decide", args: ["question": .string("?")]) == .boolean(false))
        #expect(try await MeridianTools.invoke("llm.judge") == .boolean(false))
        #expect(try await MeridianTools.invoke("totally.unknown") == .null)
    }

    @Test("mcp.call and llm.chat throw their sentinel errors")
    func notImplemented() async {
        await #expect(throws: (any Error).self) { _ = try await MeridianTools.invoke("mcp.call") }
        await #expect(throws: (any Error).self) { _ = try await MeridianTools.invoke("llm.chat") }
    }

    @Test("file.read / write / append round-trip through a temp file")
    func fileIO() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mer-tools-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("f.txt").path

        _ = try await MeridianTools.invoke("file.write", args: ["path": .string(path), "content": .string("hello")])
        let read1 = try await MeridianTools.invoke("file.read", args: ["path": .string(path)])
        #expect(read1 == .string("hello"))
        _ = try await MeridianTools.invoke("file.append", args: ["path": .string(path), "content": .string(" world")])
        #expect(try await MeridianTools.invoke("file.read", args: ["path": .string(path)]) == .string("hello world"))
        // Append to a non-existent file takes the atomic-write branch.
        let path2 = dir.appendingPathComponent("g.txt").path
        _ = try await MeridianTools.invoke("file.append", args: ["path": .string(path2), "content": .string("fresh")])
        #expect(try await MeridianTools.invoke("file.read", args: ["path": .string(path2)]) == .string("fresh"))
    }

    @Test("requiredString throws an argument-coercion error when missing")
    func requiredStringError() async {
        await #expect(throws: (any Error).self) {
            _ = try await MeridianTools.invoke("file.read", args: [:])
        }
    }
}
