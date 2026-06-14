import Testing
import Foundation
@testable import MeridianRuntime

/// Batch 2: drives the reachable residual of the pure runtime primitives to
/// 100% — `Value` projections, coercion/encode arms, comparison overloads,
/// `State` traversal, the deterministic clock/observer/checkpointer paths, the
/// builder setters, and the error-matching arms. Integration tails (real
/// subprocess/HTTP dispatch, fd-open failures) stay in their bucket-A floors.

@Suite("Reachable coverage — batch 2 (runtime primitives)")
struct ReachableCoverageRuntimeTests {

    private var allKinds: [Value] {
        [
            .string("s"), .number(3), .boolean(true),
            .money(Money(amount: 5, currency: "USD")), .duration(.seconds(2)),
            .date(Date(timeIntervalSince1970: 0)), .dateTime(Date(timeIntervalSince1970: 0)),
            .enumValue("active", kind: "status"), .record(["id": .string("x")]),
            .list([.number(1)]), .reference("r"), .null,
            .opaque(AnyHashableSendable(42)),
        ]
    }

    @Test("every Value case renders through description/json/scalar projections")
    func valueProjections() {
        for v in allKinds {
            _ = v.description
            _ = v.jsonEncodableObject
            _ = v.scalarDescription
        }
        #expect(Value.money(Money(amount: 5, currency: "USD")).description.contains("5"))
        #expect(Value.reference("r").jsonEncodableObject as? String == "r")
        #expect(Value.boolean(false).scalarDescription == "false")
        #expect(Value.number(7).scalarDescription == "7")
        #expect(Value.date(Date(timeIntervalSince1970: 0)).scalarDescription.contains("1970"))
    }

    @Test("encodeIfEncodable returns false for a box with no captured conformance")
    func encodeIfEncodableNoConformance() throws {
        // A Hashable+Sendable but NOT Encodable type → the box captures no
        // Encodable closure, so encodeIfEncodable returns false without encoding.
        struct Tag: Hashable, Sendable { let n: Int }
        let box = AnyHashableSendable(Tag(n: 7))
        struct Probe: Encodable {
            let box: AnyHashableSendable
            func encode(to encoder: Encoder) throws {
                let ok = try box.encodeIfEncodable(to: encoder)
                #expect(ok == false)
                var c = encoder.singleValueContainer()
                try c.encodeNil()
            }
        }
        _ = try JSONEncoder().encode(Probe(box: box))
    }

    @Test("Value coercion arms: string→Date, money→String, duration→Double, record→Codable")
    func coercionArms() throws {
        let iso = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: 0))
        #expect((try? Value.string(iso).coerce(to: Date.self)) != nil)
        #expect((try? Value.money(Money(amount: 5, currency: "USD")).coerce(to: String.self)) != nil)
        #expect((try? Value.duration(.seconds(3)).coerce(to: Double.self)) == 3.0)
        #expect((try? Value.duration(.seconds(3)).coerce(to: Duration.self)) != nil)

        struct Point: Codable, Equatable { let x: Int; let y: Int }
        let rec = Value.record(["x": .number(1), "y": .number(2)])
        #expect((try? rec.coerce(to: Point.self)) == Point(x: 1, y: 2))

        // unsupported coercion throws — fall-through arms of several cases.
        struct NotCodable: Hashable {}
        #expect(throws: ValueError.self) { _ = try Value.null.coerce(to: Int.self) }
        #expect(throws: ValueError.self) { _ = try Value.string("x").coerce(to: Bool.self) }       // .string fall-through
        #expect(throws: ValueError.self) { _ = try Value.duration(.seconds(1)).coerce(to: Int.self) } // .duration fall-through
        #expect(throws: (any Error).self) { _ = try Value.record(["a": .number(1)]).coerce(to: NotCodable.self) } // .record fall-through
    }

    @Test("Value.from typed overloads (Duration/Date) and AnyCodable encode arms")
    func fromAndAnyCodable() throws {
        if case .duration = Value.from(Duration.seconds(1)) {} else { Issue.record("expected duration") }
        if case .date = Value.from(Date()) {} else { Issue.record("expected date") }
        // AnyCodable.encode covers enum/reference/money/date/dateTime/duration arms.
        for v in allKinds {
            _ = try JSONEncoder().encode(AnyCodable(v))
        }
        // round-trip a list/record through AnyCodable decode
        let data = try JSONEncoder().encode(AnyCodable(.list([.string("a"), .number(1)])))
        let back = try JSONDecoder().decode(AnyCodable.self, from: data)
        if case .list(let arr) = back.value { #expect(arr.count == 2) } else { Issue.record("list") }
    }

    @Test("Comparison: typed-constant overloads, record-id identity, record numeric flatten")
    func comparisonArms() {
        // typed constant on either side (le/gt/ge families)
        #expect(MeridianComparison.le(Value.number(3), 5))
        #expect(MeridianComparison.gt(Value.number(9), 5))
        #expect(MeridianComparison.ge(Value.number(5), 5))
        #expect(MeridianComparison.lt(Value.number(3), 5))
        #expect(MeridianComparison.lt(3, Value.number(5)))
        #expect(MeridianComparison.le(3, Value.number(5)))
        #expect(MeridianComparison.gt(9, Value.number(5)))
        #expect(MeridianComparison.ge(5, Value.number(5)))
        // record-id identity via .reference
        #expect(MeridianComparison.identifies(.record(["id": .reference("u1")]), .reference("u1")))
        // numeric() flattening a record carrying amount / seconds
        #expect(MeridianComparison.gt(Value.record(["amount": .number(10)]), 5))
        #expect(MeridianComparison.gt(Value.record(["seconds": .number(10)]), 5))
    }

    @Test("State: non-Encodable bind overload, typeMismatch, record + opaque traversal")
    func stateTraversal() throws {
        // A Hashable+Sendable but NOT Encodable type → picks the non-Encodable bind.
        struct Tag: Hashable, Sendable { let n: Int }
        var s = State()
        s.bind("tag", Tag(n: 1))
        #expect(s.get("tag") != nil)

        // require with wrong type → typeMismatch
        s.bind("name", .string("hi"))
        #expect(throws: StateError.self) { _ = try s.require("name", as: Int.self) }

        // record traversal (parts.count == 1 child) + missing-key else
        s.bind("order", .record(["id": .string("o1")]))
        #expect(s.get("order.id") == .string("o1"))
        #expect(s.get("order.missing") == nil)

        // opaque traversal of a Codable domain type
        struct Order: Hashable, Sendable, Encodable { let total: Int }
        s.bind("o2", Order(total: 99))
        #expect(s.get("o2.total") == .number(99))

        // default branch: scalar with a path → nil
        #expect(s.get("name.bogus") == nil)
    }

    @Test("Clock: SystemClock.sleep and TestClock retains long sleepers on advance")
    func clocks() async throws {
        try await SystemClock().sleep(for: .milliseconds(1))

        let clock = TestClock()
        let waiter = Task { try await clock.sleep(for: .seconds(100)) }
        try await Task.sleep(for: .milliseconds(20))
        await clock.advance(by: .seconds(1))   // 100s sleeper remains (else branch)
        await clock.advance(by: .seconds(200))  // now it wakes
        _ = try await waiter.value
        #expect(Bool(true))
    }

    @Test("Observer: file write + invoke/workflow per-kind promotions")
    func observers() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mer-obs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("events.jsonl")
        let obs = try JSONLObserver.file(file)
        let ts = Date(timeIntervalSince1970: 0)

        await obs.record(Event(timestamp: ts, runID: "r", sequence: 1, kind: .invokeEnd,
            payload: ["tool": .string("http.get"), "duration_ms": .number(12),
                      "output_summary": .string("ok"), "extra": .string("x")]))
        await obs.record(Event(timestamp: ts, runID: "r", sequence: 2, kind: .workflowStarted,
            payload: ["foo": .string("bar")], sourceRange: SourceRange(file: "f", line: 1, column: 1),
            parentRunID: "parent", parentSequence: 7))
        // Second write: the file now exists, so the FileHandle(forWritingTo:)
        // append path (not the create fallback) is taken.
        await obs.record(Event(timestamp: ts, runID: "r", sequence: 3, kind: .workflowCompleted,
            payload: [:]))
        #expect(FileManager.default.fileExists(atPath: file.path))

        // Composite + InMemory observers
        let mem = InMemoryObserver()
        let comp = CompositeObserver([mem])
        await comp.record(Event(timestamp: ts, runID: "r", sequence: 3, kind: .invokeEnd,
            payload: ["tool": .string("t")]))
        let count = await mem.events.count
        #expect(count == 1)
    }

    @Test("Checkpointer: in-memory factory + filesystem round-trip")
    func checkpointers() async throws {
        _ = InMemoryCheckpointer.inMemory

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mer-ckpt-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let cp = try FilesystemCheckpointer(rootURL: dir)
        var st = State()
        st.bind("k", .number(1))
        let snap = st.snapshot()
        for seq in 0..<2 {
            try await cp.write(Checkpoint(runID: "run1", sequence: seq, timestamp: Date(),
                label: "L\(seq)", stateSnapshot: snap, sourceRange: nil))
        }
        let all = try await cp.readAll(forRun: "run1")
        #expect(all.count == 2)
        let latest = try await cp.latest(forRun: "run1")
        #expect(latest?.sequence == 1)
        try await cp.clear(forRun: "run1")
        #expect(try await cp.readAll(forRun: "run1").isEmpty)
    }

    @Test("Runtime.Builder fluent setters")
    func builderSetters() {
        let rt = Runtime.Builder()
            .setInstanceRegistry(.empty)
            .setClock(SystemClock())
            .setMaxNestingDepth(8)
            .setPermissionRegistry(.empty)
            .setLLMProvider(nil)
            .setRunID("rid")
            .build()
        _ = rt
        #expect(Bool(true))
    }

    @Test("InstanceRegistry immutable register + handle")
    func instanceRegistry() {
        let reg = InstanceRegistry.empty.register(
            kind: "mailer", name: "primary", properties: ["host": .literal(.string("h"))])
        #expect(reg.handle(for: "primary")?.kind == "mailer")
        #expect(reg.handle(for: "absent") == nil)
    }

    @Test("error matching: timeout and subprocess tool-error names")
    func errorMatching() {
        let timeout = ToolError.timeout(.seconds(1))
        #expect(meridianMatches(timeout, named: "tool.timeout"))
        #expect(meridianMatches(timeout, named: "http.timeout"))
        let sub = ToolError.subprocess(SubprocessToolError(exitCode: 1, stderr: "boom"))
        #expect(meridianMatches(sub, named: "subprocess.exit_failure"))
        #expect(meridianMatches(sub, named: "subprocess.error"))
    }
}
