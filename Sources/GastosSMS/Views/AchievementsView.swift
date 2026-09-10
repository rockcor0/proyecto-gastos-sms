import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @Query private var seenAchievements: [SeenAchievement]

    @State private var newlyUnlocked: [MonthlyAchievementResult] = []
    @State private var showCelebration = false

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
            .onAppear(perform: checkForNewAchievements)
            .sheet(isPresented: $showCelebration) {
                AchievementCelebrationView(achievements: newlyUnlocked) {
                    showCelebration = false
                }
                .presentationDetents([.medium])
            }
        }
    }

    /// Marks any tier reached since the last visit as seen (so it only celebrates once) and, if
    /// there's anything new, queues it for `AchievementCelebrationView`.
    private func checkForNewAchievements() {
        let unlocked = AchievementsEngine.newlyUnlocked(results, seen: seenAchievements)
        guard !unlocked.isEmpty else { return }

        for result in unlocked {
            guard let tier = result.tier else { continue }
            modelContext.insert(SeenAchievement(year: result.month.year, month: result.month.month, tierID: tier.id))
        }
        try? modelContext.save()

        newlyUnlocked = unlocked
        showCelebration = true
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

/// The celebration sheet shown the first time (and only the first time) a tier is reached —
/// `AchievementsView.checkForNewAchievements` decides what goes in `achievements`.
private struct AchievementCelebrationView: View {
    let achievements: [MonthlyAchievementResult]
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(achievements.count > 1 ? "¡Nuevos logros!" : "¡Nuevo logro!")
                .font(.title2.bold())
                .padding(.top, 24)

            ForEach(achievements, id: \.month) { result in
                if let tier = result.tier {
                    VStack(spacing: 6) {
                        Image(systemName: tier.systemImage)
                            .font(.system(size: 44))
                            .foregroundStyle(.yellow)
                        Text(tier.title)
                            .font(.headline)
                        Text("\(result.month.displayName) · +\(tier.points) pts")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button("Genial", action: dismiss)
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
    }
}

#Preview {
    AchievementsView()
        .modelContainer(for: [Transaction.self, CorrectionExample.self, SeenAchievement.self], inMemory: true)
}
