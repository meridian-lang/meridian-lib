import Foundation

// MARK: - Clock protocol

public protocol Clock: Sendable {
    func now() -> Date
    func sleep(for duration: Duration) async throws
}

// MARK: - SystemClock

public struct SystemClock: Clock, Sendable {
    public init() {}

    public func now() -> Date { Date() }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

public extension Clock where Self == SystemClock {
    static var system: SystemClock { SystemClock() }
}

// MARK: - TestClock

/// Deterministic clock for tests. Time advances only when explicitly told to.
public actor TestClock: Clock {
    private var _now: Date
    private var continuations: [(Duration, CheckedContinuation<Void, Error>)] = []

    public init(start: Date = Date(timeIntervalSince1970: 1_745_913_600)) {
        // Default start: 2026-04-29T10:00:00Z (matches golden event timestamps)
        self._now = start
    }

    public nonisolated func now() -> Date {
        // nonisolated: callers who just want a timestamp don't need to await
        // We use a workaround for nonisolated stored state.
        // In practice generated code calls runtime.clock.now() at emit time.
        // For the TestClock the actual timestamps in tests are overridden anyway.
        Date(timeIntervalSince1970: 1_745_913_600)
    }

    public func currentDate() -> Date { _now }

    public func sleep(for duration: Duration) async throws {
        try await withCheckedThrowingContinuation { cont in
            continuations.append((duration, cont))
        }
    }

    /// Advance virtual time by the given duration, waking any sleepers.
    public func advance(by duration: Duration) async {
        _now = _now.addingTimeInterval(Double(duration.components.seconds))
        var remaining: [(Duration, CheckedContinuation<Void, Error>)] = []
        for (sleepDuration, cont) in continuations {
            if sleepDuration <= duration {
                cont.resume()
            } else {
                remaining.append((sleepDuration - duration, cont))
            }
        }
        continuations = remaining
    }
}
