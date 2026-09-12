import SwiftUI
import SwiftData
import UIKit

struct PasteSMSView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(item: $parsedDraft) { draft in
                TransactionEditorView(mode: .create(draft: draft), onSaved: { dismiss() })
            }
        }
    }

    private func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        parsedDraft = await SMSCaptureCoordinator.draft(for: messageText, modelContext: modelContext)
    }
}
