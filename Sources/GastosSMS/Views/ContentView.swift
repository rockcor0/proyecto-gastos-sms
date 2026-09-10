import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var selectedMonth: YearMonth = .current
    @State private var showManualEntry = false
    @State private var showPasteSMS = false
    @State private var editingTransaction: Transaction?
    @State private var showDeleteError = false

    private var selectedMonthTransactions: [Transaction] {
        let interval = selectedMonth.dateInterval()
        return transactions.filter { interval.contains($0.date) }
    }

    private var monthlyTotal: Decimal {
        selectedMonthTransactions
            .filter { $0.type.isExpense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// 0 if there are no transactions in the previous month, per the product spec.
    private var previousMonthTotal: Decimal {
        let interval = selectedMonth.previous.dateInterval()
        return transactions
            .filter { interval.contains($0.date) && $0.type.isExpense }
            .reduce(Decimal.zero) { $0 + $1.amount }
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
            .alert("No se pudo eliminar", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Vuelve a intentarlo.")
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    selectedMonth = selectedMonth.previous
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text(selectedMonth.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    selectedMonth = selectedMonth.next
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .disabled(selectedMonth >= .current)
            }

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
