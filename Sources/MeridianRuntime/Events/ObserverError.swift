import Foundation

public enum ObserverError: Error, Sendable {
    case serializationFailed(TraceRecord)
    case writeFailed(path: String, underlying: String)
}
