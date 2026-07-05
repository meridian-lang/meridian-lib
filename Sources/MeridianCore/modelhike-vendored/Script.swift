// Vendored from https://github.com/modelhike/modelhike on 2026-7-5.

import Foundation

public protocol Script: Sendable, StringConvertible {
    var name: String { get }
}
