import Foundation

/// One evaluated month: its own spending trend against the month before it, and the tier that
/// trend reached (`nil` if the user didn't save that month, per `SpendingTrend.direction`).
struct MonthlyAchievementResult {
    let month: YearMonth
    let trend: SpendingTrend
    let tier: AchievementTier?
}

/// Computes achievements entirely on the fly from existing `Transaction` data — there is no
/// "unlocked achievement" record in SwiftData, so this can never drift out of sync with the
/// transactions themselves. The one thing a purely-computed result can't tell you is whether a
/// tier was *just* reached or reached months ago — `newlyUnlocked(_:seen:)` below answers that
/// using the separate `SeenAchievement` record (Fase 5), which exists only to gate the
/// celebration moment, not to recompute points or badges.
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

    private struct SeenKey: Hashable {
        let year: Int
        let month: Int
        let tierID: String
    }

    /// Results with a tier that isn't yet recorded in `seen` — the ones to celebrate.
    static func newlyUnlocked(_ results: [MonthlyAchievementResult], seen: [SeenAchievement]) -> [MonthlyAchievementResult] {
        let seenKeys = Set(seen.map { SeenKey(year: $0.year, month: $0.month, tierID: $0.tierID) })
        return results.filter { result in
            guard let tier = result.tier else { return false }
            return !seenKeys.contains(SeenKey(year: result.month.year, month: result.month.month, tierID: tier.id))
        }
    }
}
