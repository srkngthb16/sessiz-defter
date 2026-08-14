import Core
import Domain
import Foundation
import Testing

@Suite("Bütçe motoru")
struct BudgetEngineTests {
    static let calendar = Calendar.gregorianIstanbulForTests
    static let categoryID = UUID()
    static let accountID = UUID()

    static func date(_ day: Int, month: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    static var period: DateInterval { Period.month(containing: date(13), calendar: calendar) }

    static func expense(_ minorUnits: Int, day: Int, month: Int = 8,
                        categoryID: UUID? = BudgetEngineTests.categoryID) -> TransactionEntity {
        TransactionEntity(date: date(day, month: month), amount: Money(minorUnits: minorUnits),
                          direction: .expense, detail: "X", categoryID: categoryID,
                          accountID: accountID)
    }

    static func budget(limit: Int, rollsOver: Bool = false) -> BudgetEntity {
        BudgetEntity(categoryID: categoryID, limit: Money(minorUnits: limit),
                     rollsOver: rollsOver, startDate: date(1))
    }

    var engine: BudgetEngine { BudgetEngine(calendar: Self.calendar) }

    @Test("Yolunda · %68")
    func yolunda() {
        let status = engine.status(for: Self.budget(limit: 800_000),
                                   transactions: [Self.expense(545_310, day: 5)],
                                   period: Self.period, now: Self.date(13))
        #expect(status.state == .onTrack)
        #expect(abs(status.ratio - 0.6816) < 0.001)
        #expect(status.remaining.minorUnits == 254_690)
        #expect(status.overspend == nil)
        // 2.546,90 / 18 gün
        #expect(status.dailyAllowance?.minorUnits == 14_149)
    }

    @Test("Limite yakın · %80 eşiği dahil")
    func uyariEsigi() {
        let tam80 = engine.status(for: Self.budget(limit: 100_000),
                                  transactions: [Self.expense(80_000, day: 5)],
                                  period: Self.period, now: Self.date(13))
        #expect(tam80.ratio == 0.8)
        #expect(tam80.state == .warning)

        let altinda = engine.status(for: Self.budget(limit: 100_000),
                                    transactions: [Self.expense(79_999, day: 5)],
                                    period: Self.period, now: Self.date(13))
        #expect(altinda.state == .onTrack)
    }

    @Test("Aşıldı · %120 ve aşım tutarı")
    func asim() {
        let status = engine.status(for: Self.budget(limit: 260_000),
                                   transactions: [Self.expense(311_620, day: 5)],
                                   period: Self.period, now: Self.date(13))
        #expect(status.state == .exceeded)
        #expect(abs(status.ratio - 1.1985) < 0.001)
        #expect(status.overspend?.minorUnits == 51_620)
        #expect(status.dailyAllowance == nil)
    }

    @Test("Yalnızca gider sayılır; gelir, transfer, başka kategori ve dönem dışı hariç")
    func kapsam() {
        let rows = [
            Self.expense(100_000, day: 5),
            TransactionEntity(date: Self.date(6), amount: Money(minorUnits: 500_000),
                              direction: .income, detail: "Maaş",
                              categoryID: Self.categoryID, accountID: Self.accountID),
            TransactionEntity(date: Self.date(7), amount: Money(minorUnits: 200_000),
                              direction: .transfer, detail: "Transfer",
                              categoryID: Self.categoryID, accountID: Self.accountID),
            Self.expense(300_000, day: 5, categoryID: UUID()),
            Self.expense(400_000, day: 5, month: 7)
        ]
        let status = engine.status(for: Self.budget(limit: 1_000_000),
                                   transactions: rows, period: Self.period,
                                   now: Self.date(13))
        #expect(status.spent.minorUnits == 100_000)
    }

    @Test("Devreden bakiye limite eklenir")
    func devredenBakiye() {
        let without = engine.status(for: Self.budget(limit: 100_000),
                                    transactions: [], period: Self.period,
                                    now: Self.date(13), carriedOver: Money(minorUnits: 50_000))
        #expect(without.effectiveLimit.minorUnits == 100_000)

        let with = engine.status(for: Self.budget(limit: 100_000, rollsOver: true),
                                 transactions: [], period: Self.period,
                                 now: Self.date(13), carriedOver: Money(minorUnits: 50_000))
        #expect(with.effectiveLimit.minorUnits == 150_000)
    }

    @Test("Sıralama: önce aşım, sonra uyarı, sonra yolunda")
    func siralama() {
        let onTrack = BudgetEntity(categoryID: UUID(), limit: Money(minorUnits: 100_000),
                                   startDate: Self.date(1))
        let warning = BudgetEntity(categoryID: UUID(), limit: Money(minorUnits: 100_000),
                                   startDate: Self.date(1))
        let exceeded = BudgetEntity(categoryID: UUID(), limit: Money(minorUnits: 100_000),
                                    startDate: Self.date(1))
        let rows = [
            Self.expense(10_000, day: 5, categoryID: onTrack.categoryID),
            Self.expense(90_000, day: 5, categoryID: warning.categoryID),
            Self.expense(150_000, day: 5, categoryID: exceeded.categoryID)
        ]
        let statuses = engine.statuses(budgets: [onTrack, warning, exceeded],
                                       transactions: rows, period: Self.period,
                                       now: Self.date(13))
        #expect(statuses.map(\.state) == [.exceeded, .warning, .onTrack])
    }

    @Test("Genel bakış toplamları ve günlük payı")
    func genelBakis() {
        let first = BudgetEntity(categoryID: UUID(), limit: Money(minorUnits: 1_200_000),
                                 startDate: Self.date(1))
        let second = BudgetEntity(categoryID: UUID(), limit: Money(minorUnits: 800_000),
                                  startDate: Self.date(1))
        let rows = [
            Self.expense(1_090_540, day: 5, categoryID: first.categoryID),
            Self.expense(545_310, day: 5, categoryID: second.categoryID)
        ]
        let statuses = engine.statuses(budgets: [first, second], transactions: rows,
                                       period: Self.period, now: Self.date(13))
        let overview = engine.overview(statuses, daysRemaining: 18)
        #expect(overview.totalLimit.minorUnits == 2_000_000)
        #expect(overview.totalSpent.minorUnits == 1_635_850)
        #expect(overview.remaining.minorUnits == 364_150)
        #expect(overview.dailyAllowance?.minorUnits == 20_230)
    }

    @Test("Son üç ayın ortalaması")
    func ortalama() {
        let rows = [
            Self.expense(300_000, day: 10, month: 7),
            Self.expense(200_000, day: 10, month: 6),
            Self.expense(400_000, day: 10, month: 5),
            Self.expense(999_999, day: 10, month: 8)   // içinde bulunulan ay sayılmaz
        ]
        let average = engine.averageSpending(categoryID: Self.categoryID,
                                             transactions: rows,
                                             endingBefore: Self.date(13))
        #expect(average?.minorUnits == 300_000)
    }

    @Test("Harcama yoksa ortalama nil")
    func ortalamaYok() {
        #expect(engine.averageSpending(categoryID: Self.categoryID, transactions: [],
                                       endingBefore: Self.date(13)) == nil)
    }
}

extension Calendar {
    static var gregorianIstanbulForTests: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }
}
