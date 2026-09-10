import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query(sort: \Transaction.date) private var transactions: [Transaction]

    private var results: [MonthlyAchievementResult] {
        AchievementsEngine.evaluate(transactions: transactions)
    }

    private var totalPoints: Int {
        AchievementsEngine.totalPoints(results)
    }

    private var unlockedTierIDs: Set<String> {
        AchievementsEngine.unlockedTierIDs(results)
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "Sin logros todavía",
                        systemImage: "trophy",
                        description: Text("Registra tus gastos mes a mes y aquí vas a ver tus puntos por ahorrar.")
                    )
                } else {
                    List {
                        Section {
                            pointsCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        Section("Insignias") {
                            ForEach(AchievementCatalog.tiers) { tier in
                                badgeRow(for: tier)
                            }
                        }

                        Section("Historial mensual") {
                            ForEach(results.reversed(), id: \.month) { result in
                                monthRow(for: result)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logros")
        }
    }

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Puntos totales")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(totalPoints)")
                .font(.largeTitle)
                .bold()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func badgeRow(for tier: AchievementTier) -> some View {
        let unlocked = unlockedTierIDs.contains(tier.id)

        return HStack(spacing: 12) {
            Image(systemName: tier.systemImage)
                .font(.title3)
                .foregroundStyle(unlocked ? .yellow : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(tier.title)
                Text("Ahorra \(CurrencyFormatting.string(for: tier.minimumSavings, currency: .cop)) o más en un mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("+\(tier.points)")
                .font(.subheadline.bold())

            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .opacity(unlocked ? 1 : 0.5)
    }

    private func monthRow(for result: MonthlyAchievementResult) -> some View {
        HStack {
            Text(result.month.displayName)

            Spacer()

            if let tier = result.tier {
                Label("+\(tier.points)", systemImage: tier.systemImage)
                    .foregroundStyle(.green)
            } else if result.trend.direction == .worse {
                Text("Sin ahorro")
                    .foregroundStyle(.secondary)
            } else {
                Text("Sin cambio")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }
}

#Preview {
    AchievementsView()
        .modelContainer(for: [Transaction.self, CorrectionExample.self], inMemory: true)
}
