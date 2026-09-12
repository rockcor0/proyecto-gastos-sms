import Foundation
import SwiftData

/// Runs the full capture pipeline — rules first, the generative fallback only if needed — for a
/// raw SMS text, producing a ready-to-show `TransactionDraft`. Factored out of `PasteSMSView` so
/// `ContentView`'s pending-shared-message flow (Share Extension text) doesn't duplicate the
/// wiring between `SMSParsingEngine`, `GenerativeExtractionService`, and few-shot examples.
enum SMSCaptureCoordinator {
    static func draft(for rawText: String, modelContext: ModelContext) async -> TransactionDraft {
        var parsed = SMSParsingEngine.parse(rawText)
        var aiNote: String?

        if parsed.needsReview {
            if #available(iOS 26.0, *) {
                if GenerativeExtractionService.isAvailable {
                    let examples = parsed.bank.map { recentExamples(forBank: $0, modelContext: modelContext) } ?? []
                    let exampleNote = examples.isEmpty ? "sin ejemplos previos de este banco" : "con \(examples.count) ejemplo(s) de este banco"
                    let result = await GenerativeExtractionService.refine(parsed, rawText: rawText, examples: examples)
                    aiNote = "El modelo corrió (\(exampleNote)). Lo que identificó: \(result.summary)"
                    parsed = result.parsed
                } else {
                    aiNote = "El modelo on-device no está disponible en este dispositivo ahora mismo (revisa Ajustes > Apple Intelligence y Siri, o si estás en el Simulador, prueba en un iPhone físico) — solo se usaron las reglas."
                }
            } else {
                aiNote = "Este dispositivo no soporta Foundation Models (requiere iOS 26+) — solo se usaron las reglas."
            }
        }

        var draft = TransactionDraft(parsed: parsed)
        draft.aiNote = aiNote
        return draft
    }

    /// The most recent user-confirmed transactions from `bank`, used as few-shot guidance for
    /// the generative fallback. Mapped to a plain snapshot on the main actor, since SwiftData
    /// model objects shouldn't cross the `await` boundary into `refine`.
    private static func recentExamples(forBank bank: String, modelContext: ModelContext) -> [CorrectionExampleSnapshot] {
        var descriptor = FetchDescriptor<CorrectionExample>(
            predicate: #Predicate { $0.bank == bank },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 3
        let examples = (try? modelContext.fetch(descriptor)) ?? []
        return examples.map {
            CorrectionExampleSnapshot(
                rawText: $0.rawText,
                type: $0.type,
                amount: $0.amount,
                currency: $0.currency,
                merchant: $0.merchant,
                paymentMethod: $0.paymentMethod,
                category: $0.category
            )
        }
    }
}
