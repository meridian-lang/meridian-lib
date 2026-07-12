import Foundation

public enum TruthValue: String, Sendable, Codable, Equatable, CaseIterable {
    case `true`
    case `false`
    case indeterminate

    public static func from(_ bool: Bool) -> TruthValue {
        bool ? .true : .false
    }

    public func and(_ other: TruthValue) -> TruthValue {
        switch (self, other) {
        case (.false, _), (_, .false):
            return .false
        case (.true, .true):
            return .true
        default:
            return .indeterminate
        }
    }

    public func or(_ other: TruthValue) -> TruthValue {
        switch (self, other) {
        case (.true, _), (_, .true):
            return .true
        case (.false, .false):
            return .false
        default:
            return .indeterminate
        }
    }

    public func not() -> TruthValue {
        switch self {
        case .true:
            return .false
        case .false:
            return .true
        case .indeterminate:
            return .indeterminate
        }
    }
}
