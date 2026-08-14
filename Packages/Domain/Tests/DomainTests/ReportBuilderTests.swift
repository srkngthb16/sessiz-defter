import Core
import Domain
import Foundation
import Testing

@Suite("Rapor üretimi")
struct ReportBuilderTests {
    static let calendar = Calendar.gregorianIstanbulForTests
    static let accountID = UUID()
    static let market = UUID()
    static let ulasim = UUID()

    static func date(_ day: Int, _ month: Int, _ year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    static func expense(_ minorUnits: Int, _ day: Int, _ month: Int,
                        category: UUID? = market, detail: String = "MIGROS ATASEHIR")
    -> TransactionEntity {
        TransactionEntity(date: date(day, month), amount: Money(minorUnits: minorUnits),
                          direction: .expense, detail: detail,
                          categoryID: category, accountID: accountID)
    }

    static func income(_ minorUnits: Int, _ day: Int, _ month: Int) -> TransactionEntity {
        TransactionEntity(date: date(day, month), amount: Money(minorUnits: minorUnits),
                          direction: .income, detail: "MAAS", accountID: accountID)
    }

    var builder: ReportBuilder { ReportBuilder(calendar: Self.calendar) }

    @Test("Aylık trend 6 nokta, kronolojik ve Türkçe kısa ay adıyla")
    func aylikTrend() {
        let points = builder.trend([Self.expense(100_000, 10, 8),
                                    Self.income(500_000, 5, 8),
                                    Self.expense(50_000, 10, 6)],
                                   scale: .month, endingAt: Self.date(13, 8))
        #expect(points.count == 6)
        #expect(points.map(\.label) == ["Mar", "Nis", "May", "Haz", "Tem", "Ağu"])
        #expect(points.last?.income.minorUnits == 500_000)
        #expect(points.last?.expense.minorUnits == 100_000)
        #expect(points.last?.net.minorUnits == 400_000)
        #expect(points[3].expense.minorUnits == 50_000)
        #expect(points[4].expense.minorUnits == 0)
    }

    @Test("Çeyrek ve yıl ölçeği")
    func digerOlcekler() {
        let quarters = builder.trend([Self.expense(100_000, 10, 8)],
                                     scale: .quarter, endingAt: Self.date(13, 8))
        #expect(quarters.count == 4)
        #expect(quarters.last?.label == "Ç3")
        #expect(quarters.last?.expense.minorUnits == 100_000)

        let years = builder.trend([Self.expense(100_000, 10, 8),
                                   Self.expense(70_000, 10, 8)],
                                  scale: .year, endingAt: Self.date(13, 8))
        #expect(years.count == 3)
        #expect(years.map(\.label) == ["2024", "2025", "2026"])
        #expect(years.last?.expense.minorUnits == 170_000)
    }

    @Test("Dönem karşılaştırması artış ve azalışı verir")
    func karsilastirma() throws {
        let rows = [
            Self.expense(114_000, 10, 8),
            Self.expense(100_000, 10, 7),
            Self.expense(94_000, 12, 8, category: Self.ulasim, detail: "SHELL"),
            Self.expense(100_000, 12, 7, category: Self.ulasim, detail: "SHELL")
        ]
        let current = Period.month(containing: Self.date(13, 8), calendar: Self.calendar)
        let previous = Period.previousMonth(before: Self.date(13, 8), calendar: Self.calendar)
        let comparisons = builder.comparison(rows, current: current, previous: previous)

        let marketRow = try #require(comparisons.first { $0.categoryID == Self.market })
        #expect(abs((marketRow.changeRatio ?? 0) - 0.14) < 0.0001)
        #expect(marketRow.isIncrease)

        let ulasimRow = try #require(comparisons.first { $0.categoryID == Self.ulasim })
        #expect(abs((ulasimRow.changeRatio ?? 0) + 0.06) < 0.0001)
        #expect(ulasimRow.isIncrease == false)
    }

    @Test("Önceki dönem sıfırsa oran tanımsız")
    func yeniKategori() {
        let current = Period.month(containing: Self.date(13, 8), calendar: Self.calendar)
        let previous = Period.previousMonth(before: Self.date(13, 8), calendar: Self.calendar)
        let comparisons = builder.comparison([Self.expense(50_000, 10, 8)],
                                             current: current, previous: previous)
        #expect(comparisons.first?.changeRatio == nil)
        #expect(comparisons.first?.isIncrease == true)
    }

    @Test("En çok harcanan yerler: şube farkı aynı işyeridir")
    func enCokHarcanan() {
        let rows = [
            Self.expense(300_000, 5, 8, detail: "MIGROS ATASEHIR"),
            Self.expense(198_020, 8, 8, detail: "MIGROS KADIKOY"),
            Self.expense(341_000, 6, 8, category: nil, detail: "TRENDYOL SIPARISI"),
            Self.expense(318_000, 7, 8, category: Self.ulasim, detail: "SHELL OTOYOL")
        ]
        let interval = Period.month(containing: Self.date(13, 8), calendar: Self.calendar)
        let merchants = builder.topMerchants(rows, in: interval)

        #expect(merchants.count == 3)
        #expect(merchants.first?.name == "Migros")
        #expect(merchants.first?.transactionCount == 2)
        #expect(merchants.first?.total.minorUnits == 498_020)
        #expect(merchants.map { $0.name } == ["Migros", "Trendyol", "Shell"])
    }

    @Test("İşyeri anahtarı kısa ön eki atlar")
    func isyeriAnahtari() {
        #expect(ReportBuilder.merchantKey("MIGROS ATASEHIR") == "Migros")
        #expect(ReportBuilder.merchantKey("A101 BAKIRKOY") == "A101")
        #expect(ReportBuilder.merchantKey("PL MIGROS") == "Migros")
        #expect(ReportBuilder.merchantKey("") == "")
        // Türkçe harf taşıyan açıklama tr_TR kuralıyla dönüşür.
        #expect(ReportBuilder.merchantKey("ŞIŞLI ECZANESI") == "Şışlı")
        #expect(ReportBuilder.merchantKey("İSTANBUL OTOPARK") == "İstanbul")
    }

    @Test("Gelir ve transfer harcama raporlarına girmez")
    func yalnizcaGider() {
        let interval = Period.month(containing: Self.date(13, 8), calendar: Self.calendar)
        let rows = [
            Self.income(900_000, 5, 8),
            TransactionEntity(date: Self.date(6, 8), amount: Money(minorUnits: 400_000),
                              direction: .transfer, detail: "TRANSFER",
                              accountID: Self.accountID),
            Self.expense(100_000, 7, 8)
        ]
        #expect(builder.topMerchants(rows, in: interval).count == 1)
        #expect(builder.comparison(rows, current: interval, previous: interval).count == 1)
    }
}
