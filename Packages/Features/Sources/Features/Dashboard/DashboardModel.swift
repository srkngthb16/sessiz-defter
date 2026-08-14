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
            let rows = try await environment.transactions.transactions(matching: .all)
            guard !rows.isEmpty else {
                state = .empty
                return
            }
            let accounts = try await environment.accounts.all(includeArchived: true)
            let categories = try await environment.categories.all(includeArchived: true)
            let interval = Period.month(containing: environment.now(),
                                        calendar: environment.calendar)
            let monthRows = rows.filter { interval.contains($0.date) }

            state = .loaded(Content(
                netWorth: Balances.netWorth(accounts: accounts, transactions: rows),
                summary: PeriodSummary.make(from: monthRows),
                breakdown: CategoryBreakdown.make(from: monthRows, limit: 5),
                recent: Array(rows.prefix(3)),
                accountCount: accounts.count,
                periodTitle: Self.monthTitle(interval.start, calendar: environment.calendar),
                categories: CategoryLookup(categories),
                accounts: AccountLookup(accounts)))
        } catch {
            // Yerel veritabanı okunamıyorsa boş duruma düşmek, yanlış rakam göstermekten iyi.
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
