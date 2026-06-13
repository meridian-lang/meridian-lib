import Foundation

/// Emits the Swift-source fragments shared by the two workflow run drivers —
/// `RuntimeExecutor` (the `.meridian.test` subprocess runner) and
/// `SwiftPMPackageRunner` (the CLI `run` driver). Both scaffold a temp SwiftPM
/// package and write a `Driver.swift` that bridges JSON→`Value`, registers
/// closure tool stubs, and decodes workflow parameters; only the surrounding
/// shell (`@main` vs free `Task`, builtins, checkpointer) genuinely differs.
///
/// All string inputs are escaped here, so callers pass raw values. The driver
/// source is compiled and run (never golden-diffed), so a single canonical form
/// is emitted — cosmetic indent/whitespace differences between the old inline
/// copies are intentionally collapsed.
enum DriverSourceBuilder {

    /// The `valueFromJSON` / `convertAny` JSON→`Value` bridge.
    /// - Parameter includeMoneyCoercion: when `true`, a `{amount, currency}`
    ///   record decodes to `.money` (the `.meridian.test` runner relies on
    ///   this); the CLI `run` driver omits it (records stay records).
    static func jsonBridge(includeMoneyCoercion: Bool) -> [String] {
        var lines = [
            "func valueFromJSON(_ s: String) -> Value {",
            "    guard let data = s.data(using: .utf8),",
            "          let obj = try? JSONSerialization.jsonObject(with: data) else { return .string(s) }",
            "    return convertAny(obj)",
            "}",
            "func convertAny(_ obj: Any) -> Value {",
            "    if obj is NSNull { return .null }",
            "    if let s = obj as? String { return .string(s) }",
            "    if let b = obj as? Bool { return .boolean(b) }",
            "    if let n = obj as? NSNumber {",
            "        if CFGetTypeID(n) == CFBooleanGetTypeID() { return .boolean(n.boolValue) }",
            "        return .number(Decimal(string: n.stringValue) ?? 0)",
            "    }",
            "    if let arr = obj as? [Any] { return .list(arr.map(convertAny)) }",
        ]
        if includeMoneyCoercion {
            lines += [
                "    if let dict = obj as? [String: Any] {",
                "        if let amt = dict[\"amount\"] as? NSNumber,",
                "           let cur = dict[\"currency\"] as? String {",
                "            return .money(Money(amount: Decimal(string: amt.stringValue) ?? 0, currency: cur))",
                "        }",
                "        return .record(dict.mapValues(convertAny))",
                "    }",
            ]
        } else {
            lines.append("    if let dict = obj as? [String: Any] { return .record(dict.mapValues(convertAny)) }")
        }
        lines += [
            "    return .null",
            "}",
        ]
        return lines
    }

    /// Lines registering a closure tool stub that returns a fixed JSON value.
    static func toolStub(name: String, json: String, indent: String) -> [String] {
        [
            "\(indent)await registry.register(tool: \"\(escapeSwiftStringLiteral(name))\", .closure { _ in",
            "\(indent)    valueFromJSON(\"\(escapeSwiftStringLiteral(json))\")",
            "\(indent)})",
        ]
    }

    /// Lines decoding one workflow parameter from JSON.
    /// - Parameter force: `true` uses `try` and lets a decode failure propagate
    ///   (CLI `run`); `false` falls back to a zero-arg `Type()` (test runner,
    ///   which tolerates partial fixtures).
    static func paramDecode(name: String, swiftType: String, json: String, indent: String, force: Bool) -> [String] {
        let decode = force
            ? "\(indent)let \(name) = try JSONDecoder().decode(\(swiftType).self, from: _\(name)Data)"
            : "\(indent)let \(name) = (try? JSONDecoder().decode(\(swiftType).self, from: _\(name)Data)) ?? \(swiftType)()"
        return [
            "\(indent)let _\(name)Data = Data(\"\(escapeSwiftStringLiteral(json))\".utf8)",
            decode,
        ]
    }
}
