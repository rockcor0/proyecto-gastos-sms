import SwiftUI

/// The ← [month name] → row used by both `ContentView` and `MetricsView` to browse months.
/// Shared so the "no browsing into the future" rule (and its exact disabled condition) only
/// exists in one place.
struct MonthNavigationBar: View {
    @Binding var selectedMonth: YearMonth

    var body: some View {
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
    }
}
