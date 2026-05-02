import Testing
import Foundation
@testable import MeridianRuntime

@Suite("InMemoryCheckpointer")
struct CheckpointerTests {

    private func makeSnapshot(_ bindings: [String: Value] = [:]) -> StateSnapshot {
        StateSnapshot(bindings: bindings.mapValues(AnyCodable.init))
    }

    @Test("write and latest returns last checkpoint")
    func writeAndLatest() async throws {
        let cp = InMemoryCheckpointer()
        let snap = makeSnapshot(["x": .string("val")])
        let checkpoint = Checkpoint(
            runID: "r-1",
            sequence: 5,
            timestamp: Date(),
            label: "after_validation",
            stateSnapshot: snap,
            sourceRange: nil
        )
        try await cp.write(checkpoint)
        let latest = try await cp.latest(forRun: "r-1")
        #expect(latest?.label == "after_validation")
        #expect(latest?.sequence == 5)
    }

    @Test("readAll returns all checkpoints in order")
    func readAll() async throws {
        let cp = InMemoryCheckpointer()
        let snap = makeSnapshot()
        for i in 1...3 {
            try await cp.write(Checkpoint(
                runID: "r-2",
                sequence: i,
                timestamp: Date(),
                label: "label_\(i)",
                stateSnapshot: snap,
                sourceRange: nil
            ))
        }
        let all = try await cp.readAll(forRun: "r-2")
        #expect(all.count == 3)
        #expect(all[0].label == "label_1")
        #expect(all[2].label == "label_3")
    }

    @Test("latest returns nil for unknown runID")
    func latestUnknown() async throws {
        let cp = InMemoryCheckpointer()
        let latest = try await cp.latest(forRun: "nonexistent")
        #expect(latest == nil)
    }

    @Test("clear removes all checkpoints for a run")
    func clearRun() async throws {
        let cp = InMemoryCheckpointer()
        let snap = makeSnapshot()
        try await cp.write(Checkpoint(
            runID: "r-3", sequence: 1, timestamp: Date(),
            label: nil, stateSnapshot: snap, sourceRange: nil
        ))
        try await cp.clear(forRun: "r-3")
        let all = try await cp.readAll(forRun: "r-3")
        #expect(all.isEmpty)
    }

    @Test("state snapshot round-trips through checkpoint")
    func snapshotRoundTrip() async throws {
        let cp = InMemoryCheckpointer()
        let snap = makeSnapshot(["name": .string("Alice"), "count": .number(42)])
        let checkpoint = Checkpoint(
            runID: "r-4", sequence: 1, timestamp: Date(),
            label: nil, stateSnapshot: snap, sourceRange: nil
        )
        try await cp.write(checkpoint)
        let restored = try await cp.latest(forRun: "r-4")
        #expect(restored?.stateSnapshot.asValues["name"] == .string("Alice"))
        #expect(restored?.stateSnapshot.asValues["count"] == .number(42))
    }
}

// MARK: - FilesystemCheckpointer

@Suite("FilesystemCheckpointer")
struct FilesystemCheckpointerTests {

    private func makeSnapshot(_ bindings: [String: Value] = [:]) -> StateSnapshot {
        StateSnapshot(bindings: bindings.mapValues(AnyCodable.init))
    }

    /// Each test gets a fresh tmp directory; `tearDown`-style cleanup is
    /// performed on a `defer` inside each test body so that a failure leaves
    /// the directory behind for inspection.
    private func makeTempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-cp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("write + latest round-trips through disk")
    func writeAndLatest() async throws {
        let root = try makeTempRoot()
        let cp = try FilesystemCheckpointer(rootURL: root)
        let snap = makeSnapshot(["who": .string("Alice")])

        try await cp.write(Checkpoint(
            runID: "run-A", sequence: 7, timestamp: Date(),
            label: "after_validation", stateSnapshot: snap, sourceRange: nil
        ))

        let latest = try await cp.latest(forRun: "run-A")
        #expect(latest?.label == "after_validation")
        #expect(latest?.sequence == 7)
        #expect(latest?.stateSnapshot.asValues["who"] == .string("Alice"))

        try? FileManager.default.removeItem(at: root)
    }

    @Test("readAll returns numeric (not lexicographic) sequence order")
    func numericSortOrder() async throws {
        let root = try makeTempRoot()
        let cp = try FilesystemCheckpointer(rootURL: root)
        let snap = makeSnapshot()

        // Sequence interleaves single + double digit so a naive lex sort
        // would put 10 before 2.
        for seq in [1, 10, 2, 11, 3] {
            try await cp.write(Checkpoint(
                runID: "run-B", sequence: seq, timestamp: Date(),
                label: "L\(seq)", stateSnapshot: snap, sourceRange: nil
            ))
        }
        let all = try await cp.readAll(forRun: "run-B")
        #expect(all.map(\.sequence) == [1, 2, 3, 10, 11])

        try? FileManager.default.removeItem(at: root)
    }

    @Test("write is atomic — overwriting an existing sequence keeps a valid file")
    func atomicOverwrite() async throws {
        let root = try makeTempRoot()
        let cp = try FilesystemCheckpointer(rootURL: root)

        try await cp.write(Checkpoint(
            runID: "run-C", sequence: 1, timestamp: Date(),
            label: "first", stateSnapshot: makeSnapshot(["v": .number(1)]),
            sourceRange: nil
        ))
        try await cp.write(Checkpoint(
            runID: "run-C", sequence: 1, timestamp: Date(),
            label: "second", stateSnapshot: makeSnapshot(["v": .number(2)]),
            sourceRange: nil
        ))
        let latest = try await cp.latest(forRun: "run-C")
        #expect(latest?.label == "second")
        #expect(latest?.stateSnapshot.asValues["v"] == .number(2))

        // No leftover .tmp files from the rename dance.
        let runDir = root.appendingPathComponent("run-C")
        let leftovers = try FileManager.default.contentsOfDirectory(at: runDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(".tmp") }
        #expect(leftovers.isEmpty)

        try? FileManager.default.removeItem(at: root)
    }

    @Test("clear removes the run directory entirely")
    func clearRun() async throws {
        let root = try makeTempRoot()
        let cp = try FilesystemCheckpointer(rootURL: root)
        try await cp.write(Checkpoint(
            runID: "run-D", sequence: 1, timestamp: Date(),
            label: nil, stateSnapshot: makeSnapshot(), sourceRange: nil
        ))
        try await cp.clear(forRun: "run-D")
        let all = try await cp.readAll(forRun: "run-D")
        #expect(all.isEmpty)

        try? FileManager.default.removeItem(at: root)
    }

    @Test("a fresh Checkpointer reads checkpoints written by an earlier instance")
    func crossInstancePersistence() async throws {
        let root = try makeTempRoot()
        do {
            let cp = try FilesystemCheckpointer(rootURL: root)
            try await cp.write(Checkpoint(
                runID: "run-E", sequence: 5, timestamp: Date(),
                label: "stable", stateSnapshot: makeSnapshot(["k": .string("persisted")]),
                sourceRange: nil
            ))
        }
        // New process / new actor instance, same disk root.
        let cp2 = try FilesystemCheckpointer(rootURL: root)
        let latest = try await cp2.latest(forRun: "run-E")
        #expect(latest?.label == "stable")
        #expect(latest?.stateSnapshot.asValues["k"] == .string("persisted"))

        try? FileManager.default.removeItem(at: root)
    }
}
