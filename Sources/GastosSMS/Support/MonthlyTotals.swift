import Foundation

/// A named type (not a tuple) so call sites can use `id: \.month` — Swift keypaths don't reach
/// into labeled tuple elements, only positional ones (`\.0`).
struct MonthlyTotal: Hashable {
    let month: YearMonth
    let total: Decimal
}

/// Same reasoning as `MonthlyTotal`: named so `id: \.category` works.
struct CategoryTotal: Hashable {
    let category: Category
    let total: Decimal
}

/// Shared "sum of expenses" math over `Transaction` arrays, factored out once it was about to be
/// written a third time (`ContentView`, `AchievementsEngine`, and now the charts).
enum MonthlyTotals {
    static func expenseTotal(for month: YearMonth, in transactions: [Transaction]) -> Decimal {
        let interval = month.dateInterval()
        return transactions
            .filter { interval.contains($0.date) && $0.type.isExpense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Per-category totals for `month`, expenses only, highest first. Categories with no spend
    /// that month simply don't appear — there's no need to represent "$0 in Ropa" explicitly.
    static func categoryTotals(for month: YearMonth, in transactions: [Transaction]) -> [CategoryTotal] {
        let interval = month.dateInterval()
        let monthExpenses = transactions.filter { interval.contains($0.date) && $0.type.isExpense }
        let grouped = Dictionary(grouping: monthExpenses, by: \.category)
        return grouped
            .map { CategoryTotal(category: $0.key, total: $0.value.reduce(Decimal.zero) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }
}
