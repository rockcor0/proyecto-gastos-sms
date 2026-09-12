import Foundation
import SwiftData

/// The App-Group-backed store for `RawMessage`, accessed directly (not through SwiftUI's
/// `@Environment(\.modelContext)`) since that environment only carries one container at a time
/// and this needs to exist independently of — and be reachable from — the Share Extension, which
/// has no SwiftUI environment of its own to inject into.
///
/// Deliberately a separate, minimal container from the main app's `Transaction`/
/// `CorrectionExample`/`SeenAchievement` one: the shared App Group is the one piece of storage
/// that genuinely has to cross the extension/app process boundary, so it's kept to exactly that.
enum SharedInboxContainer {
    static let appGroupID = "group.com.ridel007.gastossms"

    static let shared: ModelContainer = {
        let schema = Schema([RawMessage.self])
        let configuration = ModelConfiguration(schema: schema, groupContainer: .identifier(appGroupID))
        return try! ModelContainer(for: schema, configurations: configuration)
    }()
}
