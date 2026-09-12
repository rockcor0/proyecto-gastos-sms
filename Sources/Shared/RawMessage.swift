import Foundation
import SwiftData

/// A message shared into Mecateando via the Share Extension, waiting to be parsed and confirmed
/// the next time the main app opens.
///
/// This is the *only* thing that lives in the shared App Group container — Apple's Message
/// Filter extension turned out not to support this at all (it can't write to a container shared
/// with its containing app; see the SMS-capture-roadmap analysis), which is why capture here
/// goes through a regular Share Extension instead: the user shares a message from Messages.app
/// the same way they'd share it to any other app, no special entitlement or Settings toggle
/// needed. Compiled into both the `Mecateando` and `ShareExtension` targets (via
/// `Sources/Shared` in `project.yml`) since a SwiftData model has to be linked into whichever
/// module uses it.
@Model
final class RawMessage {
    var id: UUID
    var rawText: String
    var receivedAt: Date

    init(id: UUID = UUID(), rawText: String, receivedAt: Date = .now) {
        self.id = id
        self.rawText = rawText
        self.receivedAt = receivedAt
    }
}
