import Foundation

/// A calendar year+month, independent of day/time — deliberately not just a `Date`, since
/// comparing/filtering by "this month" with a bare `Date` (via `Calendar.isDate(_:equalTo:)`)
/// is easy to get subtly wrong once the app needs to represent a month the user is *browsing*,
/// not just "today". `year`/`month` are plain `Int`s (`month` is 1...12).
struct YearMonth: Hashable, Codable, Comparable {
    var year: Int
    var month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// The year+month containing `date`. Declared explicitly (alongside `init(year:month:)`)
    /// because adding any custom initializer suppresses Swift's synthesized memberwise one.
    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        year = components.year ?? 1970
        month = components.month ?? 1
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    static var current: YearMonth {
        let components = Calendar.current.dateComponents([.year, .month], from: .now)
        return YearMonth(year: components.year!, month: components.month!)
    }

    var previous: YearMonth {
        month == 1 ? YearMonth(year: year - 1, month: 12) : YearMonth(year: year, month: month - 1)
    }

    var next: YearMonth {
        month == 12 ? YearMonth(year: year + 1, month: 1) : YearMonth(year: year, month: month + 1)
    }

    /// The date range covering this calendar month, for filtering transactions by `date`.
    func dateInterval(calendar: Calendar = .current) -> DateInterval {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let start = calendar.date(from: components) ?? .now
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    /// e.g. "Septiembre 2026".
    var displayName: String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let date = Calendar.current.date(from: components) ?? .now

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date).capitalized
    }
}
