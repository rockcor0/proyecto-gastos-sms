import SwiftUI
import SwiftData
import Charts

/// Spending charts, separated from the day-to-day dashboard (`ContentView`) per the user's
/// request — its own tab, its own month selection (independent of the Resumen tab's).
struct MetricsView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var selectedMonth: YearMonth = .current

    /// `selectedMonth` and the 5 before it, oldest first.
    private var recentMonths: [YearMonth] {
        var months: [YearMonth] = []
        var month = selectedMonth
        for _ in 0..<6 {
            months.append(month)
            month = month.previous
        }
        return months.reversed()
    }

    private var monthlyComparisonData: [MonthlyTotal] {
        recentMonths.map { MonthlyTotal(month: $0, total: MonthlyTotals.expenseTotal(for: $0, in: transactions)) }
    }

    private var categoryTotals: [CategoryTotal] {
        MonthlyTotals.categoryTotals(for: selectedMonth, in: transactions)
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "Sin datos todavía",
                        systemImage: "chart.pie",
                        description: Text("Agrega movimientos para ver tus métricas de gasto.")
                    )
                } else {
                    List {
                        Section {
                            MonthNavigationBar(selectedMonth: $selectedMonth)
                        }

                        Section("Comparación mensual") {
                            monthlyComparisonChart
                        }

                        if categoryTotals.isEmpty {
                            Section {
                                Text("Sin gastos en \(selectedMonth.displayName).")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Section("Gasto por categoría") {
                                categoryChart
                                categoryBreakdownList
                            }
                        }
                    }
                }
            }
            .navigationTitle("Métricas")
        }
    }

    /// Bar per month in `recentMonths`; the selected month is highlighted.
    private var monthlyComparisonChart: some View {
        Chart(monthlyComparisonData, id: \.month) { entry in
            BarMark(
                x: .value("Mes", entry.month.shortDisplayName),
                y: .value("Gasto", (entry.total as NSDecimalNumber).doubleValue)
            )
            .foregroundStyle(entry.month == selectedMonth ? Color.accentColor : Color.secondary.opacity(0.4))
        }
        .frame(height: 160)
        .padding(.vertical, 4)
    }

    /// Each slice uses `Category.color` directly (not Charts' auto-assigned `foregroundStyle(by:)`
    /// palette), so a category is always the same color here and in `categoryBreakdownList`/the
    /// row icons in `ContentView`.
    private var categoryChart: some View {
        Chart(categoryTotals, id: \.category) { entry in
            SectorMark(
                angle: .value("Gasto", (entry.total as NSDecimalNumber).doubleValue),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(entry.category.color)
            .cornerRadius(4)
        }
        .frame(height: 200)
        .padding(.vertical, 4)
    }

    /// Doubles as the donut chart's legend — Charts doesn't draw one for a manually-colored
    /// `foregroundStyle`, so this list (with matching colors) stands in for it.
    private var categoryBreakdownList: some View {
        ForEach(categoryTotals, id: \.category) { entry in
            HStack {
                Image(systemName: entry.category.systemImage)
                    .foregroundStyle(entry.category.color)
                Text(entry.category.displayName)
                Spacer()
                Text(CurrencyFormatting.string(for: entry.total, currency: .cop))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
    }
}

#Preview {
    MetricsView()
        .modelContainer(for: [Transaction.self, CorrectionExample.self], inMemory: true)
}
