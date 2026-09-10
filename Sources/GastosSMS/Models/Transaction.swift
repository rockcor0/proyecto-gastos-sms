import Foundation
import SwiftData

/// A single expense/income movement, entered manually or parsed from a pasted SMS.
///
/// `PersistentModel` (synthesized by `@Model`) already conforms to `Identifiable`; since this
/// class declares its own `id: UUID` property, that property satisfies the `Identifiable`
/// requirement automatically — no need to declare `: Identifiable` explicitly.
@Model
final class Transaction {
    var id: UUID
    var bank: String?
    var type: MovementType
    var amount: Decimal
    var currency: Currency
    var merchant: String?
    var paymentMethod: String?
    var date: Date
    var rawText: String?
    var confidence: Double
    var source: CaptureSource
    var needsReview: Bool

    init(
        id: UUID = UUID(),
        bank: String? = nil,
        type: MovementType = .otro,
        amount: Decimal = 0,
        currency: Currency = .cop,
        merchant: String? = nil,
        paymentMethod: String? = nil,
        date: Date = .now,
        rawText: String? = nil,
        confidence: Double = 1.0,
        source: CaptureSource = .manual,
        needsReview: Bool = false
    ) {
        self.id = id
        self.bank = bank
        self.type = type
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.paymentMethod = paymentMethod
        self.date = date
        self.rawText = rawText
        self.confidence = confidence
        self.source = source
        self.needsReview = needsReview
    }
}
