import Foundation

/// Compares one month's spend against the previous month's.
///
/// `difference = previousTotal - currentTotal`: positive means the user spent less than last
/// month (an improvement — and, per the GastosSMS achievements analysis, the amount "saved" for
/// a later phase's points system); negative means they spent more.
struct SpendingTrend {
    enum Direction {
        /// Spent less than the previous month.
        case better
        /// Spent more than the previous month.
        case worse
        /// Spent exactly the same.
        case same
    }

    let currentTotal: Decimal
    let previousTotal: Decimal

    var difference: Decimal { previousTotal - currentTotal }

    var direction: Direction {
        if difference > 0 { return .better }
        if difference < 0 { return .worse }
        return .same
    }
}
