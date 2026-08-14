import Core
import Domain
import DomainTestSupport
import Foundation
@testable import Features

enum Fixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    /// Snapshot referansları "bugün"e bağlı olmamalı; zaman sabitlenir.
    static let today = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!

    static func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
    }

    static let ziraat = AccountEntity(name: "Ziraat", kind: .checking,
                                      openingBalance: Money(minorUnits: 15_000_000),
                                      maskedNumber: "••3412", sortIndex: 0)
    static let garanti = AccountEntity(name: "Garanti", kind: .creditCard,
                                       maskedNumber: "••8871", sortIndex: 1)

    static let market = CategoryEntity(name: "Market", colorIndex: 0,
                                       symbolName: "cart", sortIndex: 0)
    static let ulasim = CategoryEntity(name: "Ulaşım", colorIndex: 1,
                                       symbolName: "car", sortIndex: 1)
    static let maas = CategoryEntity(name: "Maaş", colorIndex: 3, symbolName: "banknote",
                                     direction: .income, sortIndex: 2)

    static var transactions: [TransactionEntity] {
        [
            TransactionEntity(date: date(12), amount: Money(minorUnits: 84_260),
                              direction: .expense, detail: "Migros Ataşehir",
                              categoryID: market.id, accountID: ziraat.id),
            TransactionEntity(date: date(11), amount: Money(minorUnits: 118_000),
                              direction: .expense, detail: "Shell Otoyol",
                              categoryID: ulasim.id, accountID: garanti.id),
            TransactionEntity(date: date(5), amount: Money(minorUnits: 5_240_000),
                              direction: .income, detail: "Maaş ödemesi",
                              categoryID: maas.id, accountID: ziraat.id)
        ]
    }

    @MainActor
    static func environment(seeded: Bool = true) async -> AppEnvironment {
        let store = InMemoryStore()
        if seeded {
            await store.seed(accounts: [ziraat, garanti],
                             categories: [market, ulasim, maas],
                             transactions: transactions)
        }
        return AppEnvironment(
            transactions: InMemoryTransactionRepository(store: store),
            accounts: InMemoryAccountRepository(store: store),
            categories: InMemoryCategoryRepository(store: store),
            budgets: InMemoryBudgetRepository(store: store),
            categoryRules: InMemoryCategoryRuleRepository(store: store),
            importBatches: InMemoryImportBatchRepository(store: store),
            calendar: calendar,
            now: { today })
    }

    @MainActor
    static func loadedDashboard() async -> DashboardModel.State {
        let model = DashboardModel(environment: await environment())
        await model.load()
        return model.state
    }
}
