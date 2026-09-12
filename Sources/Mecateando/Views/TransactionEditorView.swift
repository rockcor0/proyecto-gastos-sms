import SwiftUI
import SwiftData

/// Editable, form-friendly representation of a transaction being created or edited.
struct TransactionDraft: Identifiable {
    let id = UUID()
    var bank: String = ""
    var type: MovementType = .compra
    var amountText: String = ""
    var currency: Currency = .cop
    var merchant: String = ""
    var paymentMethod: String = ""
    var category: Category = .otros
    var date: Date = .now
    var rawText: String? = nil
    var confidence: Double = 1.0
    var source: CaptureSource = .manual
    /// Set by `PasteSMSView` to explain what the generative fallback did (or why it didn't run)
    /// for this specific message — shown to the user so that behavior is never a silent guess.
    var aiNote: String? = nil

    init() {}

    init(parsed: ParsedTransaction) {
        bank = parsed.bank ?? ""
        type = parsed.type
        amountText = parsed.amount.map(Self.plainAmountString) ?? ""
        currency = parsed.currency
        merchant = parsed.merchant ?? ""
        paymentMethod = parsed.paymentMethod ?? ""
        category = parsed.category
        date = parsed.date
        rawText = parsed.rawText
        confidence = parsed.confidence
        source = .importedText
    }

    init(transaction: Transaction) {
        bank = transaction.bank ?? ""
        type = transaction.type
        amountText = Self.plainAmountString(transaction.amount)
        currency = transaction.currency
        merchant = transaction.merchant ?? ""
        paymentMethod = transaction.paymentMethod ?? ""
        category = transaction.category
        date = transaction.date
        rawText = transaction.rawText
        confidence = transaction.confidence
        source = transaction.source
    }

    /// Parses `amountText` using the device's current locale first (so it accepts whatever
    /// decimal separator the on-screen `.decimalPad` actually produced), falling back to a
    /// plain "."-decimal parse.
    var amount: Decimal? {
        let localeFormatter = NumberFormatter()
        localeFormatter.numberStyle = .decimal
        localeFormatter.locale = .current
        if let number = localeFormatter.number(from: amountText) {
            return number.decimalValue
        }
        return Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func plainAmountString(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}

enum TransactionEditorMode {
    case create(draft: TransactionDraft)
    case edit(Transaction)
}

struct TransactionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: TransactionEditorMode
    /// Called after a successful save, before this view dismisses itself. `PasteSMSView` uses
    /// this to also dismiss *itself* once the transaction it produced is saved — otherwise it
    /// stays open underneath with no obvious way to close it (see `PasteSMSView`'s doc comment).
    var onSaved: (() -> Void)?
    @State private var draft: TransactionDraft
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    init(mode: TransactionEditorMode, onSaved: (() -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .create(let draft):
            _draft = State(initialValue: draft)
        case .edit(let transaction):
            _draft = State(initialValue: TransactionDraft(transaction: transaction))
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                if let rawText = draft.rawText, !rawText.isEmpty {
                    Section("Mensaje original") {
                        Text(rawText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let aiNote = draft.aiNote {
                    Section("IA on-device") {
                        Text(aiNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Movimiento") {
                    Picker("Tipo", selection: $draft.type) {
                        ForEach(MovementType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    Picker("Categoría", selection: $draft.category) {
                        ForEach(Category.allCases) { category in
                            Label(category.displayName, systemImage: category.systemImage).tag(category)
                        }
                    }
                    DatePicker("Fecha", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Monto") {
                    TextField("Monto", text: $draft.amountText)
                        .keyboardType(.decimalPad)
                    Picker("Moneda", selection: $draft.currency) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }
                }

                Section("Detalles") {
                    TextField("Banco", text: $draft.bank)
                    TextField("Comercio", text: $draft.merchant)
                    TextField("Forma de pago", text: $draft.paymentMethod)
                }

                if isEditing {
                    Section {
                        Button("Eliminar movimiento", role: .destructive) { deleteAndDismiss() }
                    }
                }
            }
            .navigationTitle(isEditing ? "Editar movimiento" : "Nuevo movimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        // Editing mutates the live `Transaction` object directly (see
                        // `saveAndDismiss`'s `.edit` branch) before `save()` is attempted, so a
                        // cancel without a rollback would leave that in-memory mutation visible
                        // in the list even though nothing was persisted.
                        modelContext.rollback()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveAndDismiss() }
                        .disabled(draft.amount == nil)
                }
            }
            .alert("No se pudo guardar", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private func saveAndDismiss() {
        guard let amount = draft.amount else { return }

        switch mode {
        case .create:
            let transaction = Transaction(
                bank: draft.bank.isEmpty ? nil : draft.bank,
                type: draft.type,
                amount: amount,
                currency: draft.currency,
                merchant: draft.merchant.isEmpty ? nil : draft.merchant,
                paymentMethod: draft.paymentMethod.isEmpty ? nil : draft.paymentMethod,
                date: draft.date,
                rawText: draft.rawText,
                confidence: draft.confidence,
                source: draft.source,
                needsReview: draft.confidence < 0.75,
                category: draft.category
            )
            modelContext.insert(transaction)
        case .edit(let transaction):
            transaction.bank = draft.bank.isEmpty ? nil : draft.bank
            transaction.type = draft.type
            transaction.amount = amount
            transaction.currency = draft.currency
            transaction.merchant = draft.merchant.isEmpty ? nil : draft.merchant
            transaction.paymentMethod = draft.paymentMethod.isEmpty ? nil : draft.paymentMethod
            transaction.date = draft.date
            transaction.needsReview = false
            transaction.category = draft.category
        }

        recordCorrectionExampleIfNeeded(amount: amount)

        do {
            try modelContext.save()
            onSaved?()
            dismiss()
        } catch {
            // Undo the in-memory mutation/insert above so a failed save doesn't leave stale
            // data visible (e.g. the list showing an amount that was never actually persisted).
            modelContext.rollback()
            print("⚠️ Transaction save failed: \(error)")
            saveErrorMessage = "No se pudo guardar el movimiento: \(error.localizedDescription)"
            showSaveError = true
        }
    }

    /// Saves a labeled example — raw SMS text plus the values the user just confirmed — for
    /// `GenerativeExtractionService` to use as few-shot guidance next time a message from the
    /// same bank needs the generative fallback. Only meaningful when both the original text and
    /// a bank name are known, so most manual entries are skipped.
    private func recordCorrectionExampleIfNeeded(amount: Decimal) {
        guard let rawText = draft.rawText, !rawText.isEmpty else { return }
        let bank = draft.bank.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bank.isEmpty else { return }

        let example = CorrectionExample(
            bank: bank,
            rawText: rawText,
            type: draft.type,
            amount: amount,
            currency: draft.currency,
            merchant: draft.merchant.isEmpty ? nil : draft.merchant,
            paymentMethod: draft.paymentMethod.isEmpty ? nil : draft.paymentMethod,
            category: draft.category
        )
        modelContext.insert(example)
    }

    private func deleteAndDismiss() {
        guard case .edit(let transaction) = mode else {
            dismiss()
            return
        }
        modelContext.delete(transaction)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            print("⚠️ Transaction delete failed: \(error)")
            saveErrorMessage = "No se pudo eliminar el movimiento: \(error.localizedDescription)"
            showSaveError = true
        }
    }
}
