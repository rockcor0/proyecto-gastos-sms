import SwiftUI

/// App root: separates the day-to-day expense dashboard from the (future) achievements system,
/// per the monthly-navigation-and-achievements roadmap. Each tab owns its own `NavigationStack`.
struct RootTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Resumen", systemImage: "house.fill")
                }

            AchievementsView()
                .tabItem {
                    Label("Logros", systemImage: "trophy.fill")
                }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Transaction.self, CorrectionExample.self], inMemory: true)
}
