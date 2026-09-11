import XCTest
@testable import Mecateando

final class SMSParsingEngineTests: XCTestCase {

    func testLiteralCompraExample() {
        let parsed = SMSParsingEngine.parse("Compra por 18.000 pesos en Laika")

        XCTAssertEqual(parsed.amount, Decimal(18000))
        XCTAssertEqual(parsed.merchant, "Laika")
        XCTAssertEqual(parsed.type, .compra)
        XCTAssertEqual(parsed.currency, .cop)
    }

    func testBankStyleMessageWithCardAndMerchant() {
        let text = "Bancolombia le informa Compra por $85.000 en EXITO con tarjeta terminada en 4532"
        let parsed = SMSParsingEngine.parse(text)

        XCTAssertEqual(parsed.bank, "Bancolombia")
        XCTAssertEqual(parsed.amount, Decimal(85000))
        XCTAssertEqual(parsed.merchant, "EXITO")
        XCTAssertEqual(parsed.paymentMethod, "Tarjeta *4532")
        XCTAssertEqual(parsed.type, .compra)
        XCTAssertFalse(parsed.needsReview)
    }

    func testReceivedTransferIsDetected() {
        let text = "Nequi: Recibiste $120.000 de Juan Pérez"
        let parsed = SMSParsingEngine.parse(text)

        XCTAssertEqual(parsed.bank, "Nequi")
        XCTAssertEqual(parsed.type, .transferenciaRecibida)
        XCTAssertEqual(parsed.amount, Decimal(120000))
    }

    func testMissingAmountNeedsReview() {
        let text = "Davivienda: tu clave dinámica es 583920"
        let parsed = SMSParsingEngine.parse(text)

        XCTAssertNil(parsed.amount)
        XCTAssertTrue(parsed.needsReview)
        XCTAssertTrue(parsed.missingFields.contains("amount"))
    }

    func testCommaDecimalAmountNormalizesCorrectly() {
        let text = "Compra por $12.500,50 en Farmacia"
        let parsed = SMSParsingEngine.parse(text)

        XCTAssertEqual(parsed.amount, Decimal(string: "12500.50"))
        XCTAssertEqual(parsed.merchant, "Farmacia")
    }

    /// Real SMS from Banco Caja Social with no currency marker at all — no "$", "COP", or
    /// "pesos" anywhere in the message, just a bare Colombian-formatted number. Regression test
    /// for the gap `amountBareRegex` and the "pago por"/"quedó aprobado" keywords fix.
    func testBareColombianAmountWithoutCurrencyMarkerIsDetected() {
        let text = "Su pago por  2.119.221,76 para VIVIENDA Y OTROS CREDITOS quedo Aprobado. " +
            "07/14/2026 15:56. Banco Caja Social Tel Bta 601 542 6446 ? Nal 018000910038"
        let parsed = SMSParsingEngine.parse(text)

        XCTAssertEqual(parsed.bank, "Banco Caja Social")
        XCTAssertEqual(parsed.type, .pago)
        XCTAssertEqual(parsed.amount, Decimal(string: "2119221.76"))
    }

    /// Real SMS from Bancolombia using the English thousands-separator convention ("$1,000,000")
    /// instead of the Colombian one ("$1.000.000") the other tests use. Regression test for the
    /// amount regex/normalizeAmount fix and the "transferiste" keyword.
    func testEnglishThousandsSeparatorAmountAndTransferisteAreDetected() {
        let text = "Bancolombia: Transferiste $1,000,000 desde tu cuenta *9000 a la cuenta " +
            "*81000005106 el 20/08/2026 a las 15:30. ¿Dudas? Llamanos al 018000931987. Estamos cerca."
        let parsed = SMSParsingEngine.parse(text)

        XCTAssertEqual(parsed.bank, "Bancolombia")
        XCTAssertEqual(parsed.type, .transferenciaEnviada)
        XCTAssertEqual(parsed.amount, Decimal(1_000_000))
    }

    func testMerchantKeywordDetectsCategory() {
        let text = "Compra por $45.000 en RAPPI"
        let parsed = SMSParsingEngine.parse(text)

        XCTAssertEqual(parsed.category, .alimentacion)
    }

    func testUnknownMerchantFallsBackToOtrosCategory() {
        let parsed = SMSParsingEngine.parse("Compra por $10.000 en Ferreteria El Tornillo")

        XCTAssertEqual(parsed.category, .otros)
    }
}
