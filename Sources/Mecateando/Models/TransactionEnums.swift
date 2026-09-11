import Foundation
import SwiftUI

/// The kind of financial movement described by a transaction.
enum MovementType: String, Codable, CaseIterable, Identifiable {
    case compra
    case retiro
    case transferenciaEnviada
    case transferenciaRecibida
    case pago
    case otro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compra: return "Compra"
        case .retiro: return "Retiro"
        case .transferenciaEnviada: return "Transferencia enviada"
        case .transferenciaRecibida: return "Transferencia recibida"
        case .pago: return "Pago"
        case .otro: return "Otro"
        }
    }

    /// Matches a free-text label (e.g. from a generative model's output) against `displayName`.
    init?(displayName: String) {
        guard let match = MovementType.allCases.first(where: {
            $0.displayName.compare(displayName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { return nil }
        self = match
    }

    /// `true` for every movement that should count toward the monthly spend total,
    /// i.e. everything except money that arrived into the user's account.
    var isExpense: Bool {
        self != .transferenciaRecibida
    }

    var systemImage: String {
        switch self {
        case .compra: return "cart.fill"
        case .retiro: return "banknote.fill"
        case .transferenciaEnviada: return "arrow.up.right"
        case .transferenciaRecibida: return "arrow.down.left"
        case .pago: return "checkmark.circle.fill"
        case .otro: return "questionmark.circle.fill"
        }
    }
}

/// Currencies the app understands. COP is the default for Colombian bank SMS.
enum Currency: String, Codable, CaseIterable, Identifiable {
    case cop
    case usd

    var id: String { rawValue }

    var isoCode: String {
        switch self {
        case .cop: return "COP"
        case .usd: return "USD"
        }
    }

    var displayName: String {
        switch self {
        case .cop: return "Pesos (COP)"
        case .usd: return "Dólares (USD)"
        }
    }
}

/// What the money was spent on. `otros` is the mandatory fallback — every transaction gets a
/// category, even when detection (rules or the generative model) can't tell which one.
enum Category: String, Codable, CaseIterable, Identifiable {
    case vivienda
    case alimentacion
    case transporte
    case entretenimiento
    case educacion
    case salud
    case deporte
    case cuidadoPersonal
    case ropa
    case streamingSuscripciones
    case otros

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vivienda: return "Vivienda"
        case .alimentacion: return "Alimentación"
        case .transporte: return "Transporte"
        case .entretenimiento: return "Entretenimiento"
        case .educacion: return "Educación"
        case .salud: return "Salud"
        case .deporte: return "Deporte"
        case .cuidadoPersonal: return "Cuidado personal"
        case .ropa: return "Ropa"
        case .streamingSuscripciones: return "Streaming y suscripciones"
        case .otros: return "Otros"
        }
    }

    var systemImage: String {
        switch self {
        case .vivienda: return "house.fill"
        case .alimentacion: return "fork.knife"
        case .transporte: return "car.fill"
        case .entretenimiento: return "theatermasks.fill"
        case .educacion: return "graduationcap.fill"
        case .salud: return "cross.case.fill"
        case .deporte: return "figure.run"
        case .cuidadoPersonal: return "sparkles"
        case .ropa: return "tshirt.fill"
        case .streamingSuscripciones: return "tv.fill"
        case .otros: return "ellipsis.circle.fill"
        }
    }

    /// One fixed color per category — used everywhere a category shows up (row icons, chart
    /// segments, the category breakdown list) so the same color always means the same category.
    /// Matches the palette given by the user 1:1 in declaration order; `otros` isn't in that
    /// 10-color palette (there are 10 real categories + the fallback), so it gets a neutral gray
    /// instead of stealing one of the vivid colors from a real category.
    var color: Color {
        switch self {
        case .vivienda: return Color(hex: "00C2CB")
        case .alimentacion: return Color(hex: "7FE0D4")
        case .transporte: return Color(hex: "FFE38A")
        case .entretenimiento: return Color(hex: "FF9A76")
        case .educacion: return Color(hex: "FF5D8F")
        case .salud: return Color(hex: "FFCF9C")
        case .deporte: return Color(hex: "FF8C6B")
        case .cuidadoPersonal: return Color(hex: "E8543F")
        case .ropa: return Color(hex: "7C3F82")
        case .streamingSuscripciones: return Color(hex: "2C2153")
        case .otros: return Color(hex: "8E8E93")
        }
    }

    /// Matches a free-text label (e.g. from a generative model's output) against `displayName`.
    init?(displayName: String) {
        guard let match = Category.allCases.first(where: {
            $0.displayName.compare(displayName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { return nil }
        self = match
    }
}

/// How a transaction entered the app.
enum CaptureSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case importedText

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .importedText: return "SMS pegado"
        }
    }
}
