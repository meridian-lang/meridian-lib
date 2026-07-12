import Foundation

public enum ObserverError: Error, Sendable {
    case serializationFailed(Event)
    case writeFailed(path: String, underlying: String)
}
