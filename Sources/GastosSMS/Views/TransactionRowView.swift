import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.type.systemImage)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchant ?? transaction.type.displayName)
                    .font(.body)
                HStack(spacing: 4) {
                    if let bank = transaction.bank {
                        Text(bank)
                        Text("·")
                    }
                    Text(transaction.category.displayName)
                    Text("·")
                    Text(transaction.date, style: .date)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatting.string(for: transaction.amount, currency: transaction.currency))
                    .font(.body)
                if transaction.needsReview {
                    Label("Revisar", systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
