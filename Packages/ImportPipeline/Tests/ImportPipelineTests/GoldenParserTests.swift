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

/// Kredi kartı ekstrelerinin golden testleri. Bu iki fixture gerçek ekstrelerin
/// **yapısından** türetildi (kullanıcı 2026-08-17'de dört PDF verdi); işyeri
/// adları, kart ve müşteri numaraları anonimleştirildi, tutar ve tarih düzeni
/// olduğu gibi korundu — hata tam da o düzende çıkıyordu.
@Suite("Kredi kartı golden testleri")
struct CreditCardGoldenTests {
    static let calendar = Calendar.gregorianIstanbul

    @Test("Halkbank Paraf — tutar sütunu ve alt satıra düşen ödeme")
    func halkbank() throws {
        let text = try Fixture.text("halkbank-paraf-2026-08")
        let parser = HalkbankParafParser()
        #expect(parser.matches(text))

        let result = parser.parse(text, calendar: Self.calendar)
        #expect(result.rows.count == 7)

        // "05/05/2026 ORNEK MAGAZA ISTANBUL 366.60 0.00/3-": son alan kalan borç
        // ve taksit, tutar ondan önceki alan. Nokta ondalık, virgül binlik.
        let first = try #require(result.rows.first)
        #expect(first.detail == "ORNEK MAGAZA ISTANBUL")
        #expect(first.amount.minorUnits == 36_660)
        #expect(first.direction == .expense)

        // Ödeme satırında tutar bir alt satıra düşüyor ve `+` taşıyor.
        let payments = result.rows.filter { $0.direction == .income }
        #expect(payments.count == 1)
        #expect(payments.first?.detail == "Hesaptan Ödeme - Teşekkür Ederiz")
        #expect(payments.first?.amount.minorUnits == 50_000)
    }

    @Test("Garanti Bonus — iç içe geçmiş sütunlar ve bonus sütunu")
    func garantiBonus() throws {
        let text = try Fixture.text("garanti-bonus-2026-07")
        let parser = GarantiBonusParser()
        #expect(parser.matches(text))

        let result = parser.parse(text, calendar: Self.calendar)

        // Tek satıra sıkışmış iki işlem, tutarları alt satırda.
        let ulasim = result.rows.filter { $0.detail == "TOPLU TASIMA UCRETI" }
        #expect(ulasim.count == 2)
        #expect(ulasim.allSatisfy { $0.amount.minorUnits == 4_200 })

        // Bonus sütunu doluysa tutar ikinci sayıdır (3,96 bonus, 1.980,00 tutar).
        let avm = try #require(result.rows.first { $0.detail == "ORNEK ALISVERIS MERKEZI" })
        #expect(avm.amount.minorUnits == 198_000)

        // `+` ödeme, `-` bonus iadesi: ikisi de borcu azaltır.
        let odeme = try #require(result.rows.first { $0.detail.hasPrefix("ÖDEMENİZ") })
        #expect(odeme.direction == .income)
        #expect(odeme.amount.minorUnits == 612_400)
        let bonus = try #require(result.rows.first { $0.detail == "BONUS BEDAVA ALIŞVERİŞ" })
        #expect(bonus.direction == .income)

        // Başlık sayısı tutar sayısını tutmayan satır okunmaz, atlanır: devir
        // bakiyesini ilk işlemin tutarı sanmaktansa satırı rapora yazmak yeğdir.
        #expect(result.unparsed.count == 1)
    }

    @Test("Bonus ekstresi eski Garanti ayrıştırıcısına kapılmaz")
    func siralama() throws {
        let text = try Fixture.text("garanti-bonus-2026-07")
        let detected = BankFormatDetector().detect(in: text)
        #expect(detected?.formatIdentifier == "garanti.bonus.v1")
    }
}

/// Vadesiz hesap ekstreleri. Kart ekstresinden ayrı ayrıştırıcıları var; ikisi
/// karışınca para girişleri de gider yazılıyordu (kullanıcı 2026-08-17: aynı gün
/// 50.000 TL giriş ve çıkış, net varlık eksi 100.000 göründü).
@Suite("Hesap ekstresi golden testleri")
struct AccountStatementGoldenTests {
    static let calendar = Calendar.gregorianIstanbul

    @Test("Halkbank hesap özeti — işaret yönü belirler, valörlü satır da okunur")
    func halkbankHesap() throws {
        let text = try Fixture.text("halkbank-hesap-2026-08")
        let parser = HalkbankHesapOzetiParser()
        #expect(parser.matches(text))

        let result = parser.parse(text, calendar: Self.calendar)
        #expect(result.rows.count == 5)
        #expect(result.unparsed.isEmpty)

        let gelen = try #require(result.rows.first)
        #expect(gelen.direction == .income)
        #expect(gelen.amount.minorUnits == 500_000)
        #expect(gelen.runningBalance?.minorUnits == 500_000)

        let kartOdeme = result.rows[1]
        #expect(kartOdeme.direction == .expense)
        #expect(kartOdeme.amount.minorUnits == 194_758)

        // Valör tarihi ve fazladan sayı taşıyan satırda tutar, açıklamadan
        // hemen önceki iki sayının ilkidir.
        let taksitli = try #require(result.rows.first { $0.detail.contains("TAKSITLI") })
        #expect(taksitli.amount.minorUnits == 101_000)
        #expect(taksitli.direction == .expense)
        #expect(taksitli.runningBalance?.minorUnits == 115_778)
    }

    @Test("Garanti hesap hareketleri — alt satıra taşan açıklama ve işaret")
    func garantiHesap() throws {
        let text = try Fixture.text("garanti-hesap-2026-08")
        let parser = GarantiHesapHareketleriParser()
        #expect(parser.matches(text))

        let result = parser.parse(text, calendar: Self.calendar)
        #expect(result.rows.count == 4)

        let avans = try #require(result.rows.first { $0.detail.contains("Nakit Avans") })
        #expect(avans.direction == .income)
        #expect(avans.amount.minorUnits == 100_000)

        // Açıklaması alt satıra taşan kayıt: tutar taşan satırda.
        let hediye = try #require(result.rows.first { $0.detail.contains("Hediye parası") })
        #expect(hediye.direction == .income)
        #expect(hediye.amount.minorUnits == 70_000)

        let cekme = try #require(result.rows.first { $0.detail.contains("PARA ÇEKME") })
        #expect(cekme.direction == .expense)
        #expect(cekme.amount.minorUnits == 5_000_000)
    }

    @Test("Hesap ekstreleri kart ayrıştırıcılarına kapılmaz")
    func siralama() throws {
        let detector = BankFormatDetector()
        #expect(try detector.detect(in: Fixture.text("halkbank-hesap-2026-08"))?
            .formatIdentifier == "halkbank.hesapOzeti.v1")
        #expect(try detector.detect(in: Fixture.text("garanti-hesap-2026-08"))?
            .formatIdentifier == "garanti.hesapHareketleri.v1")
    }
}
