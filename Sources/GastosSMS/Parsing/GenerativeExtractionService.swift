import Foundation
import FoundationModels

/// A plain, `Sendable` snapshot of a `CorrectionExample`. SwiftData model objects are tied to a
/// `ModelContext` and shouldn't cross the `await` boundary into `refine` — callers fetch their
/// examples on the main actor and map them into this first.
struct CorrectionExampleSnapshot: Sendable {
    let rawText: String
    let type: MovementType
    let amount: Decimal
    let currency: Currency
    let merchant: String?
    let paymentMethod: String?
}

/// The outcome of a `GenerativeExtractionService.refine` call — carries not just the merged
/// transaction but a human-readable account of what actually happened, so a caller can show the
/// user (or a developer debugging a miss) exactly what the model saw, rather than only whether
/// the merge left `needsReview` true.
struct GenerativeRefinementResult {
    let parsed: ParsedTransaction
    /// What the model returned for every field, verbatim — or why it didn't run at all.
    let summary: String
}

/// Wraps Apple's on-device Foundation Models framework as the optional "Capa 2" fallback for
/// messages `SMSParsingEngine` could not fully resolve. Never required — every caller must keep
/// working when this leaves `parsed` unchanged (older iOS, ineligible device, Apple Intelligence
/// disabled, or any generation error).
@available(iOS 26.0, *)
enum GenerativeExtractionService {

    /// `true` only when the on-device model is present, the device is eligible, and Apple
    /// Intelligence is turned on. `refine` already checks this itself, but callers that want to
    /// show/hide UI (e.g. a "using on-device AI" hint) can check it directly.
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Asks the on-device model to fill in whatever `SMSParsingEngine` could not resolve.
    /// `examples` are past user-confirmed transactions from the *same* bank, shown to the model
    /// as few-shot guidance — this is the only "learning" mechanism that exists today (see the
    /// GastosSMS generative-AI analysis: there is no public API to retrain the on-device model
    /// itself). Always a best-effort refinement: returns `parsed` unchanged if the model is
    /// unavailable or generation fails for any reason, never throws.
    static func refine(
        _ parsed: ParsedTransaction,
        rawText: String,
        examples: [CorrectionExampleSnapshot] = []
    ) async -> GenerativeRefinementResult {
        guard isAvailable else {
            return GenerativeRefinementResult(parsed: parsed, summary: "El modelo no está disponible.")
        }

        let session = LanguageModelSession(
            instructions: """
            Extraes los datos de un movimiento a partir del texto de un SMS de un banco o \
            billetera colombiana (por ejemplo Bancolombia, Davivienda, Nequi, Daviplata, BBVA). \
            Responde únicamente con lo que el mensaje menciona explícitamente. No inventes ni \
            calcules montos, comercios o bancos que no estén escritos en el texto — deja esos \
            campos vacíos si no aparecen. Si se muestran ejemplos de mensajes anteriores del \
            mismo banco, úsalos solo como guía de estilo y de qué campos suele traer ese banco, \
            nunca copies sus valores en el mensaje nuevo.
            """
        )

        do {
            let response = try await session.respond(
                to: prompt(for: rawText, examples: examples),
                generating: GenerativeTransactionCandidate.self
            )
            let candidate = response.content
            let merged = candidate.merged(into: parsed, rawText: rawText)
            return GenerativeRefinementResult(parsed: merged, summary: candidate.fieldSummary)
        } catch {
            return GenerativeRefinementResult(parsed: parsed, summary: "El modelo falló al generar una respuesta: \(error.localizedDescription)")
        }
    }

    private static func prompt(for rawText: String, examples: [CorrectionExampleSnapshot]) -> String {
        guard !examples.isEmpty else {
            return "Mensaje: \(rawText)"
        }

        let exampleBlocks = examples.map { example in
            """
            Mensaje anterior del mismo banco: \(example.rawText)
            Resultado correcto — tipo: \(example.type.displayName), monto: \(example.amount), \
            moneda: \(example.currency.isoCode), comercio: \(example.merchant ?? "no aplica"), \
            forma de pago: \(example.paymentMethod ?? "no aplica")
            """
        }.joined(separator: "\n\n")

        return """
        Estos son ejemplos de mensajes anteriores del mismo banco, ya confirmados por el usuario:

        \(exampleBlocks)

        Ahora extrae los datos de este mensaje nuevo, siguiendo el mismo estilo:
        Mensaje: \(rawText)
        """
    }
}
