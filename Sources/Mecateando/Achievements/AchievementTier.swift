import Foundation

/// One level of the savings achievement system. A month reaches at most one tier — the highest
/// one its savings clear — tiers don't stack on top of each other.
struct AchievementTier: Identifiable, Equatable {
    let id: String
    let minimumSavings: Decimal
    let points: Int
    let title: String
    let systemImage: String
}

enum AchievementCatalog {
    /// Ordered from lowest to highest threshold. Starting values from the GastosSMS
    /// monthly-navigation-and-achievements analysis — adjust freely, nothing else depends on
    /// these exact numbers.
    static let tiers: [AchievementTier] = [
        AchievementTier(id: "ahorro-pequeno", minimumSavings: 10_000, points: 10, title: "Ahorro pequeño", systemImage: "leaf.fill"),
        AchievementTier(id: "buen-ahorro", minimumSavings: 50_000, points: 50, title: "Buen ahorro", systemImage: "star.fill"),
        AchievementTier(id: "gran-ahorro", minimumSavings: 100_000, points: 100, title: "Gran ahorro", systemImage: "flame.fill"),
        AchievementTier(id: "ahorro-excepcional", minimumSavings: 500_000, points: 500, title: "Ahorro excepcional", systemImage: "crown.fill")
    ]

    /// The highest tier `savings` reaches, or `nil` if it doesn't clear even the lowest one.
    static func tier(for savings: Decimal) -> AchievementTier? {
        tiers.last { savings >= $0.minimumSavings }
    }
}
