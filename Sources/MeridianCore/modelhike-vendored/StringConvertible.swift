// Vendored from https://github.com/modelhike/modelhike on 2026-7-5.

import Foundation

public protocol StringConvertible: Sendable {
    func toString() -> String
}

extension Int: StringConvertible {
    public func toString() -> String {
        "\(self)"
    }
}

extension String: StringConvertible {
    public func toString() -> String {
        self
    }
}

public typealias StringConvertibleBuilder = ResultBuilder<StringConvertible>
