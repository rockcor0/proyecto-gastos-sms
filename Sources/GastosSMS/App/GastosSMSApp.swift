import SwiftUI
import SwiftData

@main
struct GastosSMSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Transaction.self, CorrectionExample.self])
    }
}
