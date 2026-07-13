import Foundation

public enum CalendarAmountEvaluator {
  public enum Unit: String, Sendable, Equatable {
    case businessDays
    case calendarDays
    case months
  }

  public static func add(
    _ unit: Unit,
    count: Double,
    to start: Date,
    timeZone: TimeZone
  ) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let whole = Int(count.rounded(.towardZero))
    switch unit {
    case .calendarDays, .months:
      let component: Calendar.Component = unit == .months ? .month : .day
      return calendar.date(byAdding: component, value: whole, to: start) ?? start
    case .businessDays:
      var remaining = whole
      var cursor = start
      let step = whole >= 0 ? 1 : -1
      while remaining != 0 {
        cursor = calendar.date(byAdding: .day, value: step, to: cursor) ?? cursor
        let weekday = calendar.component(.weekday, from: cursor)
        if weekday != 1 && weekday != 7 {
          remaining -= step
        }
      }
      return cursor
    }
  }

  public static func timeZone(fromDeploymentZone identifier: String) -> TimeZone {
    TimeZone(identifier: identifier) ?? TimeZone(secondsFromGMT: 0) ?? .gmt
  }
}
