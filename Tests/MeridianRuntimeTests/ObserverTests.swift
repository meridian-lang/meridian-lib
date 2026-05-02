import Testing
import Foundation
@testable import MeridianRuntime

@Suite("InMemoryObserver")
struct ObserverTests {

    @Test("records events in order")
    func recordsInOrder() async throws {
        let observer = InMemoryObserver()
        let e1 = Event(timestamp: Date(), runID: "r-1", sequence: 1, kind: .workflowStarted, payload: [:])
        let e2 = Event(timestamp: Date(), runID: "r-1", sequence: 2, kind: .bind, payload: ["name": .string("x")])
        await observer.record(e1)
        await observer.record(e2)
        let events = await observer.events
        #expect(events.count == 2)
        #expect(events[0].kind == .workflowStarted)
        #expect(events[1].kind == .bind)
    }

    @Test("clear empties the store")
    func clearEmpties() async throws {
        let observer = InMemoryObserver()
        await observer.record(Event(timestamp: Date(), runID: "r-1", sequence: 1, kind: .bind, payload: [:]))
        await observer.clear()
        let events = await observer.events
        #expect(events.isEmpty)
    }

    @Test("CompositeObserver fans out to all observers")
    func compositeObserver() async throws {
        let o1 = InMemoryObserver()
        let o2 = InMemoryObserver()
        let composite = CompositeObserver([o1, o2])
        let e = Event(timestamp: Date(), runID: "r-1", sequence: 1, kind: .workflowStarted, payload: [:])
        await composite.record(e)
        let c1 = await o1.events.count
        let c2 = await o2.events.count
        #expect(c1 == 1)
        #expect(c2 == 1)
    }
}

@Suite("JSONLObserver")
struct JSONLObserverTests {

    @Test("formats workflow.started event as valid JSON")
    func formatsWorkflowStarted() async throws {
        // Capture stdout by writing to a temp file
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian_test_\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // Create the file first
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)

        let observer = try JSONLObserver.file(tmpURL)
        let event = Event(
            timestamp: Date(timeIntervalSince1970: 1_745_913_600),
            runID: "r-test",
            sequence: 1,
            kind: .workflowStarted,
            payload: ["workflow": .string("ProcessOrder")]
        )
        await observer.record(event)

        let content = try String(contentsOf: tmpURL, encoding: .utf8)
        let line = content.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(!line.isEmpty)

        // Must be valid JSON
        let data = Data(line.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["run_id"] as? String == "r-test")
        #expect(parsed?["seq"] as? Int == 1)
        #expect(parsed?["kind"] as? String == "workflow.started")
    }
}
