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
                    Image(systemName: transaction.category.systemImage)
                        .accessibilityLabel(transaction.category.displayName)
                    if let bank = transaction.bank {
                        Text(bank)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(shortDate)
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

    /// e.g. "10 Sep 2026" — compact enough to sit next to bank and category on one line.
    private var shortDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: transaction.date).capitalized
    }
}
