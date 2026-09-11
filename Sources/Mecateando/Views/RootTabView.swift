import SwiftUI

/// App root: separates the day-to-day expense dashboard, the spending charts, and the
/// achievements system into their own tabs, per the monthly-navigation-and-achievements
/// roadmap. Each tab owns its own `NavigationStack`.
struct RootTabView: View {
    /// App preference, not user data — `@AppStorage`/`UserDefaults`, not SwiftData.
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Resumen", systemImage: "house.fill")
                }

            MetricsView()
                .tabItem {
                    Label("Métricas", systemImage: "chart.pie.fill")
                }

            AchievementsView()
                .tabItem {
                    Label("Logros", systemImage: "trophy.fill")
                }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenTutorial },
            set: { isShowing in hasSeenTutorial = !isShowing }
        )) {
            OnboardingView { hasSeenTutorial = true }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Transaction.self, CorrectionExample.self, SeenAchievement.self], inMemory: true)
}
