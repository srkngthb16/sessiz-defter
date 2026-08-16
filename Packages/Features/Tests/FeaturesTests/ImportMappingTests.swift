import Core
import Domain
import DomainTestSupport
import Foundation
import ImportPipeline
import Testing
@testable import Features

@Suite("İçe aktarma eşlemesi")
@MainActor
struct ImportMappingTests {
    @Test("Anonim örnek harfleri ve rakamları maskeler")
    func anonimOrnek() {
        let masked = StatementAnonymizer.anonymize(
            "12/08/26 MIGROS ATASEHIR 842,60-\n05/08/26 MAAS ODEMESI 52.400,00+")
        #expect(masked.contains("MIGROS") == false)
        #expect(masked.contains("MAAS") == false)
        #expect(masked.contains("842") == false)
        // Satır düzeni ve ayraçlar korunmalı: biçim görünsün, içerik görünmesin.
        #expect(masked.contains("/"))
        #expect(masked.contains(","))
        #expect(masked.split(separator: "\n").count == 2)
    }

    @Test("Kaydedilen eşleme sonraki ekstrede otomatik tanınır")
    func esemeKaydiTanınir() throws {
        let text = """
        XYZ FINANS
        Ekstre
        2026-08-12 | Odeme | Market alisverisi | -842.60 | 18402.15
        """
        let profile = ParserProfileEntity(
            bankName: "XYZ Finans", formatIdentifier: "xyz.v1",
            signatures: StatementSignature.derive(from: text),
            columnMapping: [.date, .ignored, .detail, .amount, .balance],
            separator: "|")

        let detector = BankFormatDetector(savedProfiles: [profile])
        let detected = try #require(detector.detect(in: text))
        #expect(detected.formatIdentifier == "xyz.v1")
        #expect(detected.bankName == "XYZ Finans")

        let result = detected.parse(text, calendar: .gregorianIstanbul)
        #expect(result.rows.count == 1)
        #expect(result.rows.first?.detail == "Market alisverisi")
    }

    @Test("Yanlış eşleme raporu uyarı veriyor")
    func yanlisEslemeUyarisi() {
        let text = """
        12/08/26   MIGROS    842,60-   18.402,15
        11/08/26   SHELL     BOZUK     19.244,75
        09/08/26   PAPARA    BOZUK     20.424,75
        """
        let result = ZiraatVadesizParser().parse(text, calendar: .gregorianIstanbul)
        let report = ParseReport.make(from: result, text: text, bankName: "Ziraat",
                                      calendar: .gregorianIstanbul)
        #expect(report.looksWrong)
        #expect(report.parsedRows < report.candidateLines)
    }

    @Test("Doğru eşleme uyarı vermiyor")
    func dogruEsleme() {
        let text = """
        12/08/26   MIGROS    842,60-   18.402,15
        11/08/26   SHELL   1.180,00-   19.244,75
        """
        let result = ZiraatVadesizParser().parse(text, calendar: .gregorianIstanbul)
        let report = ParseReport.make(from: result, text: text, bankName: "Ziraat",
                                      calendar: .gregorianIstanbul)
        #expect(report.parsedRows == 2)
        #expect(report.looksWrong == false)
    }
}
