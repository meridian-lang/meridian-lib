// Vendored from https://github.com/modelhike/modelhike on 2026-7-5.

import Foundation

@resultBuilder
public struct ResultBuilder<T>: Sendable {
    @inlinable
    public static func buildBlock() -> [T] {
        []
    }

    @inlinable
    public static func buildBlock(_ component: T) -> [T] {
        [component]
    }

    @inlinable
    public static func buildBlock(_ components: T...) -> [T] {
        components
    }

    @inlinable
    public static func buildBlock(_ components: [T]...) -> [T] {
        components.flatMap { $0 }
    }

    @inlinable
    public static func buildOptional(_ component: [T]?) -> [T] {
        component ?? []
    }

    @inlinable
    public static func buildEither(first component: [T]) -> [T] {
        component
    }

    @inlinable
    public static func buildEither(second component: [T]) -> [T] {
        component
    }

    @inlinable
    public static func buildExpression(_ expression: T) -> [T] {
        [expression]
    }

    @inlinable
    public static func buildExpression(_ expression: [T]) -> [T] {
        expression
    }

    @inlinable
    public static func buildArray(_ components: [[T]]) -> [T] {
        components.flatMap { $0 }
    }

    @inlinable
    public static func buildLimitedAvailability(_ components: [T]) -> [T] {
        components
    }
}
