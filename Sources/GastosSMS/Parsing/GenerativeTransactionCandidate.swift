import Foundation
import FoundationModels

/// Structured output shape for the on-device model. Fields are plain strings — not
/// `MovementType`/`Currency` directly — so mapping a surprising model output back into the
/// app's own enums stays an explicit, defensive step in `merged(into:rawText:)` below, rather
/// than relying on unverified `Generable` conformance for those enums.
@available(iOS 26.0, *)
@Generable(description: "Datos de un movimiento extraídos de un SMS bancario colombiano.")
struct GenerativeTransactionCandidate {
    @Guide(description: "Banco o billetera que envía el mensaje, tal como aparece en el texto. Vacío si no se menciona.")
    var bank: String?

    @Guide(description: "Tipo de movimiento: Compra, Retiro, Transferencia enviada, Transferencia recibida, Pago, u Otro.")
    var movementType: String

    @Guide(description: "El monto, solo dígitos y como mucho un separador decimal con punto, sin símbolo de moneda ni separador de miles — por ejemplo 18000 o 12500.50. Vacío si no aparece.")
    var amount: String?

    @Guide(description: "Código de moneda: COP o USD. COP si el mensaje no menciona ninguna.")
    var currency: String

    @Guide(description: "Nombre del comercio donde se hizo la compra, si aparece en el texto. Vacío si no aplica.")
    var merchant: String?

    @Guide(description: "Forma de pago mencionada, por ejemplo 'Tarjeta terminada en 1234' o 'Nequi'. Vacío si no se menciona.")
    var paymentMethod: String?
}

@available(iOS 26.0, *)
extension GenerativeTransactionCandidate {
    /// Every field the model returned, verbatim and unmapped — before any merging with the rule
    /// engine's result or any attempt to parse `amount` into a `Decimal`. This is the ground
    /// truth for diagnosing a miss: if `amount` shows here as "—", the model itself didn't find
    /// it in the text; if it shows a value but the saved transaction still lacks an amount, the
    /// bug is in `merged(into:rawText:)`'s parsing instead.
    var fieldSummary: String {
        "banco: \(bank ?? "—") · tipo: \(movementType) · monto: \(amount ?? "—") · " +
        "moneda: \(currency) · comercio: \(merchant ?? "—") · forma de pago: \(paymentMethod ?? "—")"
    }

    /// Fills only the fields `parsed` left empty — `SMSParsingEngine`'s own findings always win,
    /// since a regex match on a known format is more trustworthy than a generative guess.
    func merged(into parsed: ParsedTransaction, rawText: String) -> ParsedTransaction {
        var result = parsed

        if result.bank == nil, let bank, !bank.isEmpty {
            result.bank = bank
        }
        if result.merchant == nil, let merchant, !merchant.isEmpty {
            result.merchant = merchant
        }
        if result.paymentMethod == nil, let paymentMethod, !paymentMethod.isEmpty {
            result.paymentMethod = paymentMethod
        }
        if result.amount == nil, let amount {
            result.amount = Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX"))
        }
        if result.type == .otro, let mapped = MovementType(displayName: movementType) {
            result.type = mapped
        }
        if let mappedCurrency = Currency(rawValue: currency.lowercased()) {
            result.currency = mappedCurrency
        }

        let merchantMatters = (result.type == .compra || result.type == .pago)
        var missingFields: [String] = []
        if result.bank == nil { missingFields.append("bank") }
        if result.amount == nil { missingFields.append("amount") }
        if result.merchant == nil, merchantMatters { missingFields.append("merchant") }
        result.missingFields = missingFields

        var confidence = 1.0
        if result.bank == nil { confidence -= 0.15 }
        if result.amount == nil { confidence -= 0.5 }
        if result.merchant == nil, merchantMatters { confidence -= 0.2 }
        if result.type == .otro { confidence -= 0.15 }
        result.confidence = max(0, min(1, confidence))

        return result
    }
}
