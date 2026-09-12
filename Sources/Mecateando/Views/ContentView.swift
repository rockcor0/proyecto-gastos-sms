import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedMonth: YearMonth = .current
    @State private var showManualEntry = false
    @State private var showPasteSMS = false
    @State private var editingTransaction: Transaction?
    @State private var showDeleteError = false

    // Messages shared in from the Share Extension (see SharedInboxContainer), processed one at a
    // time: pendingMessageID identifies which RawMessage pendingDraft came from, so the sheet's
    // outcome (saved vs. cancelled) can be applied to the right row when it closes.
    @State private var pendingDraft: TransactionDraft?
    @State private var pendingMessageID: UUID?
    @State private var pendingMessageWasHandled = false
    @State private var skippedMessageIDs: Set<UUID> = []

    private var selectedMonthTransactions: [Transaction] {
        let interval = selectedMonth.dateInterval()
        return transactions.filter { interval.contains($0.date) }
    }

    private var monthlyTotal: Decimal {
        MonthlyTotals.expenseTotal(for: selectedMonth, in: transactions)
    }

    /// 0 if there are no transactions in the previous month, per the product spec.
    private var previousMonthTotal: Decimal {
        MonthlyTotals.expenseTotal(for: selectedMonth.previous, in: transactions)
    }

    private var spendingTrend: SpendingTrend {
        SpendingTrend(currentTotal: monthlyTotal, previousTotal: previousMonthTotal)
    }

    private var pendingReviewCount: Int {
        transactions.filter { $0.needsReview }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "Sin movimientos",
                        systemImage: "creditcard",
                        description: Text("Agrega un movimiento manualmente o pega el texto de un SMS bancario.")
                    )
                } else {
                    List {
                        Section {
                            summaryCard
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }

                        if selectedMonthTransactions.isEmpty {
                            Section {
                                Text("Sin movimientos en \(selectedMonth.displayName).")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Section("Movimientos") {
                                ForEach(selectedMonthTransactions) { transaction in
                                    TransactionRowView(transaction: transaction)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            editingTransaction = transaction
                                        }
                                }
                                .onDelete(perform: deleteTransactions)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mecateando")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showManualEntry = true
                        } label: {
                            Label("Agregar manualmente", systemImage: "square.and.pencil")
                        }
                        Button {
                            showPasteSMS = true
                        } label: {
                            Label("Pegar mensaje de SMS", systemImage: "text.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showManualEntry) {
                TransactionEditorView(mode: .create(draft: TransactionDraft()))
            }
            .sheet(isPresented: $showPasteSMS) {
                PasteSMSView()
            }
            .sheet(item: $editingTransaction) { transaction in
                TransactionEditorView(mode: .edit(transaction))
            }
            .sheet(item: $pendingDraft, onDismiss: onPendingSheetDismissed) { draft in
                TransactionEditorView(mode: .create(draft: draft), onSaved: markPendingMessageHandled)
            }
            .alert("No se pudo eliminar", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Vuelve a intentarlo.")
            }
        }
        .task { await checkPendingSharedMessages() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await checkPendingSharedMessages() }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonthNavigationBar(selectedMonth: $selectedMonth)

            Text(CurrencyFormatting.string(for: monthlyTotal, currency: .cop))
                .font(.largeTitle)
                .bold()

            trendIndicator

            if pendingReviewCount > 0 {
                Label("\(pendingReviewCount) movimiento(s) necesitan revisión", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var trendIndicator: some View {
        let amount = CurrencyFormatting.string(for: abs(spendingTrend.difference), currency: .cop)

        switch spendingTrend.direction {
        case .better:
            Label("\(amount) menos que el mes anterior", systemImage: "arrow.up")
                .font(.footnote)
                .foregroundStyle(.green)
        case .worse:
            Label("\(amount) más que el mes anterior", systemImage: "arrow.down")
                .font(.footnote)
                .foregroundStyle(.red)
        case .same:
            Label("Igual que el mes anterior", systemImage: "minus")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Looks in the Share Extension's inbox for a message not already being shown or skipped
    /// this session, runs it through the same capture pipeline as `PasteSMSView`, and presents it
    /// for confirmation. Safe to call repeatedly (on appear, on becoming active, after each
    /// pending sheet closes) — it no-ops while a draft is already up.
    private func checkPendingSharedMessages() async {
        guard pendingDraft == nil else { return }

        let context = SharedInboxContainer.shared.mainContext
        let descriptor = FetchDescriptor<RawMessage>(sortBy: [SortDescriptor(\.receivedAt)])
        guard let messages = try? context.fetch(descriptor),
              let next = messages.first(where: { !skippedMessageIDs.contains($0.id) }) else {
            return
        }

        pendingMessageID = next.id
        pendingMessageWasHandled = false
        pendingDraft = await SMSCaptureCoordinator.draft(for: next.rawText, modelContext: modelContext)
    }

    /// `TransactionEditorView.onSaved` for the pending-message sheet — removes the `RawMessage`
    /// from the shared inbox now that it became a real `Transaction`.
    private func markPendingMessageHandled() {
        pendingMessageWasHandled = true
        guard let id = pendingMessageID else { return }

        let context = SharedInboxContainer.shared.mainContext
        let descriptor = FetchDescriptor<RawMessage>(predicate: #Predicate { $0.id == id })
        if let message = try? context.fetch(descriptor).first {
            context.delete(message)
            try? context.save()
        }
    }

    /// Fires whether the sheet closed by saving or by being cancelled/swiped away. If it wasn't
    /// saved, the `RawMessage` stays in the inbox — but gets skipped for the rest of this app
    /// session, so cancelling doesn't just immediately re-show the same message.
    private func onPendingSheetDismissed() {
        if !pendingMessageWasHandled, let id = pendingMessageID {
            skippedMessageIDs.insert(id)
        }
        pendingMessageID = nil
        Task { await checkPendingSharedMessages() }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        let monthTransactions = selectedMonthTransactions
        for index in offsets {
            modelContext.delete(monthTransactions[index])
        }
        do {
            try modelContext.save()
        } catch {
            showDeleteError = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
