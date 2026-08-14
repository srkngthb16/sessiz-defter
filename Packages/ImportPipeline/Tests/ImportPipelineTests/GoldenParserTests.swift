import Core
import Domain
import Foundation
import Testing
@testable import ImportPipeline

/// Her banka formatı için golden test: beklenen işlem sayısı, tutar toplamı, tarih aralığı.
/// Fixture metinleri sentetiktir — gerçek ekstre örneği verilmedi, biçim tasarım
/// dosyasındaki C7 ham satır önizlemesinden türetildi.
@Suite("Golden parser testleri")
struct GoldenParserTests {
    static let calendar = Calendar.gregorianIstanbul

    static func date(_ day: Int, _ month: Int, _ year: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Ziraat vadesiz — 6 işlem, toplam ve tarih aralığı")
    func ziraat() throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let result = ZiraatVadesizParser().parse(text, calendar: Self.calendar)

        #expect(result.rows.count == 6)
        #expect(result.unparsed.isEmpty)
        // 842,60 + 1.180,00 + 1.250,00 + 318,40 + 52.400,00 + 59,99
        #expect(result.totalAmount.minorUnits == 5_605_099)
        #expect(result.dateRange == Self.date(3, 8, 2026)...Self.date(12, 8, 2026))

        let expenses = result.rows.filter { $0.direction == .expense }
        let incomes = result.rows.filter { $0.direction == .income }
        #expect(expenses.count == 5)
        #expect(incomes.count == 1)
        #expect(incomes.first?.detail == "MAAS ODEMESI")
        #expect(incomes.first?.amount.minorUnits == 5_240_000)

        let migros = try #require(result.rows.first)
        #expect(migros.detail == "MIGROS ATASEHIR")
        #expect(migros.amount.minorUnits == 84_260)
        #expect(migros.direction == .expense)
        #expect(migros.runningBalance?.minorUnits == 1_840_215)
        #expect(migros.confidence == 1.0)
    }

    @Test("Ziraat — eksi bakiye işaretiyle okunur")
    func ziraatEksiBakiye() throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let result = ZiraatVadesizParser().parse(text, calendar: Self.calendar)
        let spotify = try #require(result.rows.first { $0.detail == "SPOTIFY ABONELIK" })
        #expect(spotify.runningBalance?.minorUnits == -3_040_685)
    }

    @Test("Garanti kredi kartı — 4 işlem, iade gelir yönünde")
    func garanti() throws {
        let text = try Fixture.text("garanti-kredikarti-2026-06")
        let result = GarantiKrediKartiParser().parse(text, calendar: Self.calendar)

        #expect(result.rows.count == 4)
        #expect(result.unparsed.isEmpty)
        // 2.340,00 + 128,00 + 394,25 + 180,00
        #expect(result.totalAmount.minorUnits == 304_225)
        #expect(result.dateRange == Self.date(1, 6, 2026)...Self.date(8, 6, 2026))

        let iade = try #require(result.rows.first { $0.detail.contains("IADE") })
        #expect(iade.direction == .income)
        #expect(iade.amount.minorUnits == 18_000)
        #expect(result.rows.filter { $0.direction == .expense }.count == 3)
    }

    @Test("Format tespiti doğru parser'ı seçer")
    func formatTespiti() throws {
        let detector = BankFormatDetector()
        let ziraat = try Fixture.text("ziraat-vadesiz-2026-08")
        let garanti = try Fixture.text("garanti-kredikarti-2026-06")
        let unknown = try Fixture.text("taninmayan-banka")

        #expect(detector.detect(in: ziraat)?.formatIdentifier == "ziraat.vadesiz.v1")
        #expect(detector.detect(in: garanti)?.formatIdentifier == "garanti.krediKarti.v1")
        #expect(detector.detect(in: unknown) == nil)
    }

    @Test("Tanınmayan format kullanıcı sütun eşlemesiyle okunur, güven düşük")
    func genelSutunEslemesi() throws {
        let text = try Fixture.text("taninmayan-banka")
        let parser = GenericColumnParser(
            formatIdentifier: "xyz.genel.v1", bankName: "XYZ Finans",
            separator: "|", columns: [.date, .ignored, .detail, .amount, .balance])
        let result = parser.parse(text, calendar: Self.calendar)

        #expect(result.rows.count == 3)
        #expect(result.totalAmount.minorUnits == 5_442_260)
        #expect(result.rows.allSatisfy { $0.confidence < 1.0 })
        let maas = try #require(result.rows.first { $0.detail == "Maas" })
        #expect(maas.direction == .income)
        #expect(maas.amount.minorUnits == 5_240_000)
    }

    @Test("Bozuk satır atılmaz, kontrol listesine düşer")
    func bozukSatir() {
        let text = """
        12/08/26   MIGROS ATASEHIR                      842,60-        18.402,15
        11/08/26   SHELL OTOYOL                         BOZUK          19.244,75
        """
        let result = ZiraatVadesizParser().parse(text, calendar: Self.calendar)
        #expect(result.rows.count == 1)
        #expect(result.unparsed.count == 1)
        #expect(result.unparsed.first?.lineNumber == 2)
        #expect(result.unparsed.first?.text.contains("SHELL") == true)
    }
}
