import Foundation

/// The result of running `SMSParsingEngine` over a raw SMS text.
struct ParsedTransaction {
    var bank: String?
    var type: MovementType
    var amount: Decimal?
    var currency: Currency
    var merchant: String?
    var paymentMethod: String?
    var date: Date
    var rawText: String
    var confidence: Double
    var missingFields: [String]
    /// Always has a value — `.otros` is a valid, non-failing guess, so this never affects
    /// `confidence`/`missingFields`/`needsReview` the way a missing amount or bank does.
    var category: Category = .otros

    /// Low confidence or a missing amount both mean a human should confirm this before saving.
    var needsReview: Bool {
        confidence < 0.75 || amount == nil
    }
}
