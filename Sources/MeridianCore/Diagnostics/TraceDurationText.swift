import Foundation

/// Human-readable duration rendering for trace diagnostics (MER-TMP-011). This
/// is problem-message text, not canonical language surface — it renders a
/// window/retention span in the largest whole unit that divides it evenly so
/// `SEM-4-06` errors can name both durations the way an author wrote them
/// (`90 days`, `30 days`) rather than in raw seconds.
enum TraceDurationText {
    private static let units: [(name: String, seconds: Double)] = [
        ("week", 60 * 60 * 24 * 7),
        ("day", 60 * 60 * 24),
        ("hour", 60 * 60),
        ("minute", 60),
        ("second", 1),
    ]

    static func window(_ window: (Double, TimeUnitAST)) -> String {
        seconds(window.0 * Double(window.1.inSeconds))
    }

    static func seconds(_ total: Double) -> String {
        guard total > 0 else { return "0 seconds" }
        for unit in units where total.truncatingRemainder(dividingBy: unit.seconds) == 0 {
            let count = total / unit.seconds
            return format(count, unit: unit.name)
        }
        return format(total, unit: "second")
    }

    private static func format(_ count: Double, unit: String) -> String {
        let whole = count.rounded()
        let countText = count == whole ? String(Int(whole)) : String(count)
        return "\(countText) \(unit)\(count == 1 ? "" : "s")"
    }
}
