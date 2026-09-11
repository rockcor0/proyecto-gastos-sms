import SwiftUI
import SwiftData

@main
struct MecateandoApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Transaction.self, CorrectionExample.self, SeenAchievement.self])
    }
}
