import SwiftUI
import SwiftData
import UIKit
import FoundationModels

struct PasteSMSView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var messageText: String = ""
    @State private var parsedDraft: TransactionDraft?
    @State private var isAnalyzing = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pega o escribe el texto del SMS bancario. Mecateando intentará extraer el monto, el comercio y el banco automáticamente; podrás corregir cualquier dato antes de guardar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextEditor(text: $messageText)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button {
                    if let clipboardText = UIPasteboard.general.string {
                        messageText = clipboardText
                    }
                } label: {
                    Label("Pegar desde el portapapeles", systemImage: "doc.on.clipboard")
                }

                Spacer()

                Button {
                    Task { await analyze() }
                } label: {
                    Group {
                        if isAnalyzing {
                            ProgressView()
                        } else {
                            Text("Analizar mensaje")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)
            }
            .padding()
            .navigationTitle("Pegar mensaje de SMS")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $parsedDraft) { draft in
                TransactionEditorView(mode: .create(draft: draft))
            }
        }
    }

    /// Runs the rule engine first (fast, always available); if it couldn't resolve the message
    /// with confidence, asks the on-device generative model (iOS 26+, Apple Intelligence only)
    /// to fill in the gaps before showing the confirmation form. Never blocks on the model being
    /// unavailable — `GenerativeExtractionService.refine` degrades to a no-op in that case. Every
    /// path sets `aiNote` on the resulting draft so the confirmation screen always says whether
    /// the model ran, why it didn't, and whether the examples helped — this was previously a
    /// silent black box.
    private func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        var parsed = SMSParsingEngine.parse(messageText)
        var aiNote: String?

        if parsed.needsReview {
            if #available(iOS 26.0, *) {
                if GenerativeExtractionService.isAvailable {
                    let examples = parsed.bank.map(recentExamples(forBank:)) ?? []
                    let exampleNote = examples.isEmpty ? "sin ejemplos previos de este banco" : "con \(examples.count) ejemplo(s) de este banco"
                    let result = await GenerativeExtractionService.refine(parsed, rawText: messageText, examples: examples)
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
        parsedDraft = draft
    }

    /// The most recent user-confirmed transactions from `bank`, used as few-shot guidance for
    /// the generative fallback. Fetched and mapped to a plain snapshot here, on the main actor,
    /// since SwiftData model objects shouldn't cross the `await` boundary into `refine`.
    private func recentExamples(forBank bank: String) -> [CorrectionExampleSnapshot] {
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
                paymentMethod: $0.paymentMethod
            )
        }
    }
}
