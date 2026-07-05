// Vendored from https://github.com/modelhike/modelhike on 2026-7-5.

import Foundation

public protocol Template: StringConvertible, Sendable {
    var name: String { get }
}
