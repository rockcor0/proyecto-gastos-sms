import Foundation

/// One evaluated month: its own spending trend against the month before it, and the tier that
/// trend reached (`nil` if the user didn't save that month, per `SpendingTrend.direction`).
struct MonthlyAchievementResult {
    let month: YearMonth
    let trend: SpendingTrend
    let tier: AchievementTier?
}

/// Computes achievements entirely on the fly from existing `Transaction` data — there is no
/// "unlocked achievement" record in SwiftData. Simpler, and it can never drift out of sync with
/// the transactions themselves. The tradeoff (accepted for now, see the GastosSMS
/// monthly-navigation-and-achievements analysis): no persisted history of *when* something was
/// first unlocked, so no "you just earned a new badge!" celebration moment is possible without
/// adding that persistence later.
enum AchievementsEngine {

    /// Evaluates every calendar month from the earliest transaction through the current month
    /// (inclusive) — including months with zero transactions, since a quiet month right after a
    /// big-spend month is still a legitimate save. Each month is compared to the one before it.
    static func evaluate(transactions: [Transaction]) -> [MonthlyAchievementResult] {
        guard let earliest = transactions.map({ YearMonth(date: $0.date) }).min() else {
            return []
        }

        func total(for month: YearMonth) -> Decimal {
            let interval = month.dateInterval()
            return transactions
                .filter { interval.contains($0.date) && $0.type.isExpense }
                .reduce(Decimal.zero) { $0 + $1.amount }
        }

        var results: [MonthlyAchievementResult] = []
        var month = earliest
        let latest = YearMonth.current

        while month <= latest {
            let trend = SpendingTrend(currentTotal: total(for: month), previousTotal: total(for: month.previous))
            let tier = trend.direction == .better ? AchievementCatalog.tier(for: trend.difference) : nil
            results.append(MonthlyAchievementResult(month: month, trend: trend, tier: tier))
            month = month.next
        }

        return results
    }

    static func totalPoints(_ results: [MonthlyAchievementResult]) -> Int {
        results.compactMap { $0.tier?.points }.reduce(0, +)
    }

    /// Every tier reached in at least one month, for the badge list.
    static func unlockedTierIDs(_ results: [MonthlyAchievementResult]) -> Set<String> {
        Set(results.compactMap { $0.tier?.id })
    }
}
