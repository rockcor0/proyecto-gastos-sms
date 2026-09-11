import Foundation
import SwiftData

/// A confirmed transaction the user saved from a pasted SMS, kept as a labeled example so the
/// generative fallback (`GenerativeExtractionService`) can be shown a few real, correct examples
/// for the same bank before parsing a new message — the "Nivel 1" learning described in the
/// GastosSMS generative-AI architecture analysis. Never sent anywhere off-device; read only
/// locally, keyed by bank name.
@Model
final class CorrectionExample {
    var id: UUID
    var bank: String
    var rawText: String
    var type: MovementType
    var amount: Decimal
    var currency: Currency
    var merchant: String?
    var paymentMethod: String?
    var createdAt: Date
    var category: Category = Category.otros

    init(
        id: UUID = UUID(),
        bank: String,
        rawText: String,
        type: MovementType,
        amount: Decimal,
        currency: Currency,
        merchant: String? = nil,
        paymentMethod: String? = nil,
        createdAt: Date = .now,
        category: Category = .otros
    ) {
        self.id = id
        self.bank = bank
        self.rawText = rawText
        self.type = type
        self.amount = amount
        self.currency = currency
        self.merchant = merchant
        self.paymentMethod = paymentMethod
        self.createdAt = createdAt
        self.category = category
    }
}
