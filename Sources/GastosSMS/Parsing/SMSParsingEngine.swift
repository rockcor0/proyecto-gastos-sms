import Foundation

/// Parses the raw text of a Colombian bank/wallet SMS into a best-effort `ParsedTransaction`.
///
/// IMPORTANT: most of the bank name list and the patterns below are still generic heuristics
/// based on commonly documented SMS formats, not verified against a real message from every
/// bank — refine them further as real SMS samples turn up. Real samples have already shaped this
/// file twice: a Banco Caja Social payment confirmation with no currency marker at all (no
/// "$"/"COP"/"pesos") is why `amountBareRegex` and the "pago por"/"quedó aprobado" keywords
/// exist; a Bancolombia transfer SMS ("Transferiste $1,000,000...") revealed that not every
/// message uses the Colombian "." -thousands/","-decimal convention — some use the English one
/// instead — which is why the amount regexes and `normalizeAmount` accept either, and why
/// "transferiste" is in the keyword list. The engine still intentionally avoids per-bank "exact
/// template" regexes it can't verify — each fix here is a generic pattern broad enough to
/// plausibly apply beyond the one message that revealed the gap, not a one-off special case.
/// Category detection (`detectCategory`) is a best-effort keyword match, not verified against
/// real data at all yet — `.otros` is always a safe, non-failing fallback.
enum SMSParsingEngine {

    // MARK: - Known banks (canonical name + alternate spellings that may appear in an SMS)

    private static let knownBanks: [(canonical: String, aliases: [String])] = [
        ("Bancolombia", ["Bancolombia"]),
        ("Davivienda", ["Davivienda"]),
        ("Nequi", ["Nequi"]),
        ("Daviplata", ["Daviplata"]),
        ("BBVA", ["BBVA"]),
        ("Banco de Bogotá", ["Banco de Bogotá", "Banco de Bogota"]),
        ("Scotiabank Colpatria", ["Scotiabank Colpatria", "Colpatria"]),
        ("Banco Caja Social", ["Banco Caja Social", "Caja Social"])
    ]

    // MARK: - Keyword-based movement type detection (checked in order; first match wins)

    private static let movementKeywords: [(MovementType, [String])] = [
        (.transferenciaRecibida, ["recibiste", "transferencia recibida", "te transfirieron", "consignaron a tu cuenta"]),
        (.transferenciaEnviada, ["enviaste", "transferiste", "transferencia enviada", "envío realizado", "envio realizado"]),
        (.retiro, ["retiro"]),
        (.pago, ["pago de", "pago por", "pago exitoso", "pago realizado", "factura pagada", "quedó aprobado"]),
        (.compra, ["compra"])
    ]

    // MARK: - Regular expressions
    //
    // NOTE: NSRegularExpression.Options has no diacritic-insensitive flag (that only exists on
    // String.CompareOptions for range(of:options:)). Every pattern below is written so it does
    // not need one: accent variants that matter are spelled out explicitly in character classes
    // (e.g. `d[ií]a`), and everything else that could contain accents (bank names, keywords) is
    // matched with `range(of:options:)` instead of a regex — see the detect* helpers below.

    /// "$18.000" or "COP 18.000", optionally with decimals: "$12.500,50" or, the English
    /// grouping convention seen in a real Bancolombia transfer SMS, "$1,000,000". Accepts either
    /// "." or "," as a separator at each position — `normalizeAmount` figures out afterward,
    /// from how many digits follow the *last* separator, which one was being used as the decimal
    /// point (if any) in this particular match.
    private static let amountPrefixedRegex = try! NSRegularExpression(
        pattern: #"(?:\$|COP)\s?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?)"#
    )

    /// "18.000 pesos" / "18.000 COP" (or the English-grouping equivalent) — requires at least
    /// one separator group so we don't misread arbitrary digit runs (dates, OTP codes) as an
    /// amount.
    private static let amountSuffixedRegex = try! NSRegularExpression(
        pattern: #"(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)\s?(?:pesos|COP)"#,
        options: [.caseInsensitive]
    )

    /// Last-resort fallback: a bare formatted number with no currency marker at all (no
    /// "$"/"COP"/"pesos") — real-world case found in a Banco Caja Social SMS: "Su pago por
    /// 2.119.221,76 para VIVIENDA Y OTROS CREDITOS quedó Aprobado". Still requires at least one
    /// separator group, so it doesn't false-match a bare date or phone number in the rest of the
    /// message (Colombian dates use "/", phone numbers here have no separators at all).
    private static let amountBareRegex = try! NSRegularExpression(
        pattern: #"(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?)"#
    )

    /// "tarjeta terminada en 1234"
    private static let cardRegex = try! NSRegularExpression(
        pattern: #"tarjeta\s+terminada\s+en\s+(\d{3,4})"#,
        options: [.caseInsensitive]
    )

    /// Merchant name after "en ", stopping at a handful of common continuations, a comma/period,
    /// or the end of the string.
    private static let merchantRegex = try! NSRegularExpression(
        pattern: #"\ben\s+([^.,\n]+?)(?=\s+(?:con|a\s+las|el\s+d[ií]a)\b|[.,]|$)"#,
        options: [.caseInsensitive]
    )

    // MARK: - Public API

    static func parse(_ rawText: String, receivedAt: Date = .now) -> ParsedTransaction {
        let bank = detectBank(in: rawText)
        let type = detectType(in: rawText)
        let currency = detectCurrency(in: rawText)
        let amount = extractAmount(in: rawText)
        let merchant = extractMerchant(in: rawText)
        let paymentMethod = extractPaymentMethod(in: rawText)
        let category = detectCategory(merchant: merchant, in: rawText)
        let merchantMatters = (type == .compra || type == .pago)

        var missingFields: [String] = []
        if bank == nil { missingFields.append("bank") }
        if amount == nil { missingFields.append("amount") }
        if merchant == nil, merchantMatters { missingFields.append("merchant") }

        var confidence = 1.0
        if bank == nil { confidence -= 0.15 }
        if amount == nil { confidence -= 0.5 }
        if merchant == nil, merchantMatters { confidence -= 0.2 }
        if type == .otro { confidence -= 0.15 }
        confidence = max(0, min(1, confidence))

        return ParsedTransaction(
            bank: bank,
            type: type,
            amount: amount,
            currency: currency,
            merchant: merchant,
            paymentMethod: paymentMethod,
            date: receivedAt,
            rawText: rawText,
            confidence: confidence,
            missingFields: missingFields,
            category: category
        )
    }

    // MARK: - Detection helpers (literal, diacritic/case-insensitive substring search)

    private static func detectBank(in text: String) -> String? {
        for entry in knownBanks {
            for alias in entry.aliases {
                if text.range(of: alias, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    return entry.canonical
                }
            }
        }
        return nil
    }

    private static func detectType(in text: String) -> MovementType {
        for (type, keywords) in movementKeywords {
            for keyword in keywords {
                if text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    return type
                }
            }
        }
        return .otro
    }

    private static func detectCurrency(in text: String) -> Currency {
        let usdKeywords = ["usd", "dólares", "dolares", "us$"]
        for keyword in usdKeywords {
            if text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                return .usd
            }
        }
        return .cop
    }

    // MARK: - Extraction helpers (regex, for dynamic substrings)

    private static func extractAmount(in text: String) -> Decimal? {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        if let match = amountPrefixedRegex.firstMatch(in: text, range: fullRange),
           let range = Range(match.range(at: 1), in: text) {
            return normalizeAmount(String(text[range]))
        }
        if let match = amountSuffixedRegex.firstMatch(in: text, range: fullRange),
           let range = Range(match.range(at: 1), in: text) {
            return normalizeAmount(String(text[range]))
        }
        if let match = amountBareRegex.firstMatch(in: text, range: fullRange),
           let range = Range(match.range(at: 1), in: text) {
            return normalizeAmount(String(text[range]))
        }
        return nil
    }

    private static func extractMerchant(in text: String) -> String? {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = merchantRegex.firstMatch(in: text, range: fullRange),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let merchant = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
        return merchant.isEmpty ? nil : merchant
    }

    private static func extractPaymentMethod(in text: String) -> String? {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = cardRegex.firstMatch(in: text, range: fullRange),
           let range = Range(match.range(at: 1), in: text) {
            return "Tarjeta *\(String(text[range]))"
        }
        if text.range(of: "nequi", options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return "Nequi"
        }
        return nil
    }

    /// Normalizes an amount string into a `Decimal`, accepting either grouping convention:
    /// Colombian ("." thousands / "," decimal, e.g. "12.500,50") or English ("," thousands /
    /// "." decimal, e.g. "1,000,000.50" — seen in a real Bancolombia transfer SMS). Whichever
    /// separator appears *last* and is followed by exactly 1-2 digits is the decimal point for
    /// this particular number; the other character is a thousands separator and gets stripped.
    /// If the last separator is instead followed by 3 digits, there's no decimal part at all —
    /// both characters are just thousands separators.
    private static func normalizeAmount(_ raw: String) -> Decimal? {
        let posix = Locale(identifier: "en_US_POSIX")

        guard let lastSeparatorIndex = raw.lastIndex(where: { $0 == "." || $0 == "," }) else {
            return Decimal(string: raw, locale: posix)
        }

        let digitsAfterSeparator = raw.distance(from: raw.index(after: lastSeparatorIndex), to: raw.endIndex)
        let decimalSeparator = raw[lastSeparatorIndex]

        guard digitsAfterSeparator == 1 || digitsAfterSeparator == 2 else {
            return Decimal(string: raw.filter { $0 != "." && $0 != "," }, locale: posix)
        }

        let thousandsSeparator: Character = decimalSeparator == "," ? "." : ","
        var normalized = raw.filter { $0 != thousandsSeparator }
        if decimalSeparator == "," {
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }
        return Decimal(string: normalized, locale: posix)
    }

    // MARK: - Category detection (best-effort; `.otros` is always a valid, non-failing result)

    private static let categoryKeywords: [(Category, [String])] = [
        (.vivienda, ["arriendo", "alquiler", "administracion", "administración", "acueducto", "energia", "energía", "gas natural", "hipoteca"]),
        (.alimentacion, ["restaurante", "supermercado", "mercado", "domicilios", "rappi", "panaderia", "panadería", "cafe", "café"]),
        (.transporte, ["uber", "didi", "cabify", "taxi", "gasolina", "combustible", "peaje", "transmilenio", "parqueadero"]),
        (.entretenimiento, ["cine", "cinemark", "cinepolis", "cinépolis", "procinal", "teatro", "concierto", "boleteria", "boletería"]),
        (.educacion, ["universidad", "colegio", "matricula", "matrícula"]),
        (.salud, ["farmacia", "drogueria", "droguería", "eps", "clinica", "clínica", "hospital", "copago"]),
        (.deporte, ["gimnasio", "bodytech", "smart fit", "crossfit"]),
        (.cuidadoPersonal, ["peluqueria", "peluquería", "spa", "barberia", "barbería"]),
        (.ropa, ["zara", "falabella", "calzado"]),
        (.streamingSuscripciones, ["netflix", "spotify", "disney", "hbo", "amazon prime", "youtube premium", "apple music", "paramount"])
    ]

    /// Checks the merchant name first (if any), then the full message text. Returns `.otros`
    /// — never nil — when nothing matches; that's an expected outcome, not a failure, so it
    /// never affects `confidence`/`missingFields` the way a missing amount or bank does.
    private static func detectCategory(merchant: String?, in text: String) -> Category {
        if let merchant {
            for (category, keywords) in categoryKeywords {
                for keyword in keywords where merchant.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    return category
                }
            }
        }
        for (category, keywords) in categoryKeywords {
            for keyword in keywords where text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                return category
            }
        }
        return .otros
    }
}
