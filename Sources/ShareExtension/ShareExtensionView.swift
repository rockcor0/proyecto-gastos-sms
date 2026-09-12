import SwiftUI

/// The extension's only screen: show what was shared, save it to the App Group inbox for
/// Mecateando to parse next time it opens, and close. No parsing happens here — the extension
/// only has to capture the text as fast and reliably as possible.
struct ShareExtensionView: View {
    let sharedText: String?
    let onFinish: () -> Void

    @State private var didSave = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let sharedText, !sharedText.isEmpty {
                    Image(systemName: didSave ? "checkmark.circle.fill" : "text.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(didSave ? .green : .accentColor)

                    Text(didSave ? "Guardado" : "¿Guardar este mensaje en Mecateando?")
                        .font(.headline)

                    Text(sharedText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if didSave {
                        Text("Ábrela para confirmar los datos.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("No se pudo leer texto de este mensaje.")
                        .font(.headline)
                }

                Spacer()

                if !didSave, let sharedText, !sharedText.isEmpty {
                    Button {
                        save(sharedText)
                    } label: {
                        Text("Guardar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Mecateando")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSave ? "Listo" : "Cancelar", action: onFinish)
                }
            }
        }
    }

    private func save(_ text: String) {
        let context = SharedInboxContainer.shared.mainContext
        context.insert(RawMessage(rawText: text))
        try? context.save()
        didSave = true
    }
}

#Preview {
    ShareExtensionView(sharedText: "Bancolombia: Compra por $18.000 en Laika", onFinish: {})
}
