import Core
import Domain
import DomainTestSupport
import Foundation
import Testing

@Suite("Domain servisleri")
struct ServiceTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    static func date(_ day: Int, month: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    @Test("Hesap bakiyesi açılış artı gelir eksi gider")
    func hesapBakiyesi() {
        let account = AccountEntity(name: "Ziraat", kind: .checking,
                                    openingBalance: Money(minorUnits: 100_000))
        let rows = [
            TransactionEntity(date: Self.date(1), amount: Money(minorUnits: 50_000),
                              direction: .income, detail: "Maaş", accountID: account.id),
            TransactionEntity(date: Self.date(2), amount: Money(minorUnits: 20_000),
                              direction: .expense, detail: "Market", accountID: account.id)
        ]
        #expect(Balances.balance(of: account, transactions: rows).minorUnits == 130_000)
    }

    @Test("Transfer net varlığı değiştirmez, iki hesabı ters yönde etkiler")
    func transferBakiyesi() {
        let source = AccountEntity(name: "Ziraat", kind: .checking,
                                   openingBalance: Money(minorUnits: 100_000))
        let target = AccountEntity(name: "Garanti", kind: .creditCard,
                                   openingBalance: Money(minorUnits: 0))
        let rows = [
            TransactionEntity(date: Self.date(3), amount: Money(minorUnits: 25_000),
                              direction: .transfer, detail: "Papara → Ziraat",
                              accountID: source.id, counterpartAccountID: target.id)
        ]
        #expect(Balances.balance(of: source, transactions: rows).minorUnits == 75_000)
        #expect(Balances.balance(of: target, transactions: rows).minorUnits == 25_000)
        #expect(Balances.netWorth(accounts: [source, target], transactions: rows).minorUnits
                == 100_000)
    }

    @Test("Dönem özeti transferi saymaz")
    func donemOzeti() {
        let accountID = UUID()
        let summary = PeriodSummary.make(from: [
            TransactionEntity(date: Self.date(1), amount: Money(minorUnits: 60_000),
                              direction: .income, detail: "Maaş", accountID: accountID),
            TransactionEntity(date: Self.date(2), amount: Money(minorUnits: 25_000),
                              direction: .expense, detail: "Market", accountID: accountID),
            TransactionEntity(date: Self.date(3), amount: Money(minorUnits: 90_000),
                              direction: .transfer, detail: "Transfer", accountID: accountID)
        ])
        #expect(summary.income.minorUnits == 60_000)
        #expect(summary.expense.minorUnits == 25_000)
        #expect(summary.net.minorUnits == 35_000)
    }

    @Test("Kategori dağılımı azalan sırada ve limit üstü Diğer'de toplanır")
    func kategoriDagilimi() {
        let accountID = UUID()
        let ids = (0..<4).map { _ in UUID() }
        let rows = [
            (ids[0], 40_000), (ids[1], 30_000), (ids[2], 20_000), (ids[3], 10_000)
        ].map { pair in
            TransactionEntity(date: Self.date(1), amount: Money(minorUnits: pair.1),
                              direction: .expense, detail: "X",
                              categoryID: pair.0, accountID: accountID)
        }

        let full = CategoryBreakdown.make(from: rows, limit: 8)
        #expect(full.count == 4)
        #expect(full.first?.amount.minorUnits == 40_000)
        #expect(abs((full.first?.share ?? 0) - 0.4) < 0.0001)

        let capped = CategoryBreakdown.make(from: rows, limit: 2)
        #expect(capped.count == 3)
        #expect(capped.last?.categoryID == nil)
        #expect(capped.last?.amount.minorUnits == 30_000)
    }

    @Test("Gün grupları azalan tarihte, gün toplamı transfer içermez")
    func gunGruplari() {
        let accountID = UUID()
        let rows = [
            TransactionEntity(date: Self.date(12), amount: Money(minorUnits: 84_260),
                              direction: .expense, detail: "Migros", accountID: accountID),
            TransactionEntity(date: Self.date(12), amount: Money(minorUnits: 12_800),
                              direction: .expense, detail: "Kahve", accountID: accountID),
            TransactionEntity(date: Self.date(11), amount: Money(minorUnits: 125_000),
                              direction: .transfer, detail: "Transfer", accountID: accountID)
        ]
        let groups = TransactionService.group(rows, calendar: Self.calendar)
        #expect(groups.count == 2)
        #expect(groups.first?.total.minorUnits == -97_060)
        #expect(groups.last?.total.minorUnits == 0)
    }

    @Test("Ay aralığı ve kalan gün sayısı")
    func donemler() {
        let interval = Period.month(containing: Self.date(13), calendar: Self.calendar)
        #expect(Self.calendar.component(.day, from: interval.start) == 1)
        #expect(Self.calendar.component(.month, from: interval.end) == 8)
        #expect(Period.remainingDays(in: interval, from: Self.date(13),
                                     calendar: Self.calendar) == 18)

        let previous = Period.previousMonth(before: Self.date(13), calendar: Self.calendar)
        #expect(Self.calendar.component(.month, from: previous.start) == 7)
    }

    @Test("Kategori seed yalnızca tablo boşken yazılır")
    func kategoriSeed() async throws {
        let store = InMemoryStore()
        let service = TransactionService(
            transactions: InMemoryTransactionRepository(store: store),
            accounts: InMemoryAccountRepository(store: store),
            categories: InMemoryCategoryRepository(store: store))

        #expect(try await service.seedDefaultCategoriesIfNeeded() == true)
        let count = try await InMemoryCategoryRepository(store: store)
            .all(includeArchived: true).count
        #expect(count == 16)
        #expect(try await service.seedDefaultCategoriesIfNeeded() == false)
    }

    @Test("Hesap seed yalnızca hiç hesap yokken çalışır")
    func hesapSeed() async throws {
        let store = InMemoryStore()
        let service = TransactionService(
            transactions: InMemoryTransactionRepository(store: store),
            accounts: InMemoryAccountRepository(store: store),
            categories: InMemoryCategoryRepository(store: store))

        #expect(try await service.seedDefaultAccountIfNeeded() == true)
        let accounts = try await InMemoryAccountRepository(store: store)
            .all(includeArchived: true)
        #expect(accounts.map(\.name) == ["Nakit"])
        #expect(try await service.seedDefaultAccountIfNeeded() == false)
    }
}
