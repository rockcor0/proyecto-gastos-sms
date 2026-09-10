import Foundation
import SwiftData

/// Marks that the celebration for reaching `tierID` in a given month has already been shown.
/// `AchievementsEngine` recomputes everything fresh from `Transaction` data every time — without
/// this record there would be no way to tell "just unlocked" from "unlocked months ago", so the
/// celebration would either never show or show every time the Logros tab opens.
///
/// `year`/`month` are stored as plain `Int`s rather than `YearMonth` directly — `YearMonth` isn't
/// a `@Model` type, and keeping this record's storage to plain primitives avoids any uncertainty
/// about how SwiftData persists/queries a custom `Codable` struct property.
@Model
final class SeenAchievement {
    var id: UUID
    var year: Int
    var month: Int
    var tierID: String
    var seenAt: Date

    init(id: UUID = UUID(), year: Int, month: Int, tierID: String, seenAt: Date = .now) {
        self.id = id
        self.year = year
        self.month = month
        self.tierID = tierID
        self.seenAt = seenAt
    }
}
