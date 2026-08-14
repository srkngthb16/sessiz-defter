import Core
import Foundation
import Testing
@testable import ImportPipeline

@Suite("Alan ayrıştırma")
struct FieldParserTests {
    @Test("Tutar: binlik nokta, ondalık virgül, sondaki işaret")
    func tutarBicimleri() throws {
        let cases: [(String, Int, Bool)] = [
            ("842,60-", 84260, true),
            ("1.180,00-", 118000, true),
            ("52.400,00+", 5240000, false),
            ("2.340,00 TL", 234000, false),
            ("-180,00 TL", 18000, true),
            ("59,99", 5999, false),
            ("18402.15", 1840215, false),
            ("1.250", 125000, false)
        ]
        for (raw, expected, negative) in cases {
            let parsed = try #require(AmountParser.parse(raw), "okunamadı: \(raw)")
            #expect(parsed.amount.minorUnits == expected, "\(raw)")
            #expect(parsed.isNegative == negative, "\(raw)")
        }
    }

    @Test("Geçersiz tutar nil döner")
    func gecersizTutar() {
        #expect(AmountParser.parse("") == nil)
        #expect(AmountParser.parse("ABC") == nil)
        #expect(AmountParser.parse("12,345") == nil)
    }

    @Test("Tarih biçimleri")
    func tarihBicimleri() throws {
        let calendar = Calendar.gregorianIstanbul
        let expected = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!
        for raw in ["12/08/26", "12.08.2026", "12/08/2026", "2026-08-12"] {
            #expect(StatementDateParser.parse(raw, calendar: calendar) == expected,
                    "\(raw)")
        }
        #expect(StatementDateParser.parse("32/13/26", calendar: calendar) == nil)
        #expect(StatementDateParser.parse("MIGROS", calendar: calendar) == nil)
    }

    @Test("İmza eşleşmesi Türkçe karakter ve harf durumuna takılmaz")
    func imzaEslesmesi() {
        #expect(TextNormalizer.fold("T.C. ZİRAAT BANKASI") == "T.C. ZIRAAT BANKASI")
        #expect(ZiraatVadesizParser().matches("t.c. zıraat bankası a.ş. hesap özeti"))
        #expect(ZiraatVadesizParser().matches("GARANTI BBVA KREDI KARTI") == false)
    }
}
