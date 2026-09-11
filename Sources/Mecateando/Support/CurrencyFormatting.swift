import Foundation

/// Formats amounts as Colombian-locale currency strings (no decimals for COP).
enum CurrencyFormatting {
    static func string(for amount: Decimal, currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_CO")
        formatter.currencyCode = currency.isoCode
        let fractionDigits = currency == .cop ? 0 : 2
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
}
