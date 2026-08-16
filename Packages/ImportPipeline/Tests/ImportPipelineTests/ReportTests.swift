import Core
import Domain
import Foundation
import Testing
@testable import ImportPipeline

@Suite("Ayrıştırma raporu ve anonimleştirme")
struct ReportTests {
    static let calendar = Calendar.gregorianIstanbul

    @Test("Rapor satır sayılarını ve atlama nedenlerini toplar")
    func rapor() throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let result = ZiraatVadesizParser().parse(text, calendar: Self.calendar)
        let report = ParseReport.make(from: result, text: text, bankName: "Ziraat Bankası",
                                      calendar: Self.calendar)

        #expect(report.parsedRows == 6)
        #expect(report.candidateLines >= 6)
        #expect(report.totalLines > report.candidateLines)
        #expect(report.looksWrong == false)
        #expect(report.summaryLine.contains("6 işlem okundu"))
    }

    @Test("Yanlış eşleme raporda görünür")
    func yanlisEsleme() {
        let text = """
        12/08/26   MIGROS ATASEHIR                      842,60-        18.402,15
        11/08/26   SHELL OTOYOL                         BOZUK          19.244,75
        09/08/26   PAPARA ODEME                         BOZUK          20.424,75
        """
        let result = ZiraatVadesizParser().parse(text, calendar: Self.calendar)
        let report = ParseReport.make(from: result, text: text, bankName: "Ziraat",
                                      calendar: Self.calendar)
        #expect(report.parsedRows == 1)
        #expect(report.candidateLines == 3)
        #expect(report.looksWrong)
        #expect(report.skippedRows[.noAmount] == 2)
    }

    @Test("Anonimleştirme rakamları ve harfleri maskeler, düzeni korur")
    func anonimlestirme() {
        let masked = StatementAnonymizer.maskLine(
            "12/08/26   MIGROS ATASEHIR    842,60-   18.402,15")
        #expect(masked == "99/99/99   XXXXXX XXXXXXXX    999,99-   99.999,99")
        #expect(masked.contains("MIGROS") == false)
        #expect(masked.contains("842") == false)
    }

    @Test("Anonimleştirme satır sayısını sınırlar")
    func satirSiniri() {
        let text = (0..<100).map { "SATIR \($0)" }.joined(separator: "\n")
        let masked = StatementAnonymizer.anonymize(text, maxLines: 10)
        #expect(masked.split(separator: "\n").count == 10)
    }

    @Test("İmza sayı taşımayan başlık satırlarından türer")
    func imzaTuretme() throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let signatures = StatementSignature.derive(from: text)
        #expect(signatures.isEmpty == false)
        #expect(signatures.allSatisfy { !$0.contains(where: \.isNumber) })
        #expect(signatures.first?.contains("ZIRAAT") == true)
    }

    @Test("Kaydedilmiş profil parser'a dönüşür ve imzayla eşleşir")
    func kayitliProfil() throws {
        let text = try Fixture.text("taninmayan-banka")
        let profile = ParserProfileEntity(
            bankName: "XYZ Finans", formatIdentifier: "xyz.genel.v1",
            signatures: StatementSignature.derive(from: text),
            columnMapping: [.date, .ignored, .detail, .amount, .balance])
        let parser = try #require(GenericColumnParser(profile: profile))

        #expect(parser.matches(text))
        let detector = BankFormatDetector(savedProfiles: [profile])
        #expect(detector.detect(in: text)?.formatIdentifier == "xyz.genel.v1")
    }

    @Test("İmzasız ya da eşlemesiz profil parser üretmez")
    func gecersizProfil() {
        #expect(GenericColumnParser(profile: ParserProfileEntity(
            bankName: "X", formatIdentifier: "x", signatures: [],
            columnMapping: [.date, .amount])) == nil)
        #expect(GenericColumnParser(profile: ParserProfileEntity(
            bankName: "X", formatIdentifier: "x", signatures: ["IMZA"],
            columnMapping: [])) == nil)
    }
}
