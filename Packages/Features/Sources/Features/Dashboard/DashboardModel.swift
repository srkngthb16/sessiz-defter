import Core
import Domain
import Foundation

@Observable
@MainActor
public final class DashboardModel {
    public struct Content: Sendable {
        public var netWorth: Money
        public var summary: PeriodSummary
        public var breakdown: [CategoryBreakdownItem]
        public var recent: [TransactionEntity]
        public var budgets: [BudgetStatus]
        public var accountCount: Int
        public var periodTitle: String
        public var categories: CategoryLookup
        public var accounts: AccountLookup
    }

    public enum State {
        case loading
        case empty
        case loaded(Content)
    }

    public private(set) var state: State = .loading
    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func load() async {
        do {
            try await environment.service.seedDefaultCategoriesIfNeeded()
            try await environment.service.seedDefaultAccountIfNeeded()
            // Defterin tamamı okunmuyor: bakiye toplamlardan, ay kartları dönem
            // sorgusundan, son işlemler sınırlı sorgudan geliyor. 10.000 kayıtta
            // hepsini çekmek açılışı 450 ms'ye çıkarıyordu.
            guard try await environment.transactions.count(matching: .all) > 0 else {
                state = .empty
                return
            }
            let accounts = try await environment.accounts.all(includeArchived: true)
            let categories = try await environment.categories.all(includeArchived: true)
            let interval = Period.month(containing: environment.now(),
                                        calendar: environment.calendar)
            var monthQuery = TransactionQuery.all
            monthQuery.dateRange = interval.start...interval.end
            let monthRows = try await environment.transactions.transactions(matching: monthQuery)
            var recentQuery = TransactionQuery.all
            recentQuery.limit = 3
            let recentRows = try await environment.transactions.transactions(matching: recentQuery)
            let signedTotals = try await environment.transactions.signedTotalsByAccount()

            let budgets = try await environment.budgets.all(includeArchived: false)
            let engine = BudgetEngine(calendar: environment.calendar)
            // Dashboard yalnızca dikkat isteyenleri gösterir; tamamı Bütçe sekmesinde.
            let statuses = engine.statuses(budgets: budgets, transactions: monthRows,
                                           period: interval, now: environment.now())
                .filter { $0.state != .onTrack }

            state = .loaded(Content(
                netWorth: Balances.netWorth(accounts: accounts, signedTotals: signedTotals),
                summary: PeriodSummary.make(from: monthRows),
                breakdown: CategoryBreakdown.make(from: monthRows, limit: 5),
                recent: recentRows,
                budgets: Array(statuses.prefix(2)),
                accountCount: accounts.count,
                periodTitle: Self.monthTitle(interval.start, calendar: environment.calendar),
                categories: CategoryLookup(categories),
                accounts: AccountLookup(accounts)))
        } catch {
            // Yerel veritabanı okunamıyorsa boş duruma düşmek, yanlış rakam göstermekten iyi.
            environment.diagnostics.record(.dataRead)
            state = .empty
        }
    }

    static func monthTitle(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = TurkishLocale.locale
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
