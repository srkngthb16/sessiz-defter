import Core
import Domain
import Foundation

@Observable
@MainActor
public final class ReportsModel {
    public struct Content: Sendable {
        public var points: [PeriodPoint]
        public var comparisons: [CategoryComparison]
        public var merchants: [MerchantTotal]
        public var currentLabel: String
        public var previousLabel: String
        public var categories: CategoryLookup
    }

    public enum State {
        case loading
        case empty
        case loaded(Content)
    }

    public private(set) var state: State = .loading
    public var scale: ReportScale = .month

    private let environment: AppEnvironment

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public func load() async {
        do {
            let rows = try await environment.transactions.transactions(matching: .all)
            guard !rows.isEmpty else {
                state = .empty
                return
            }
            let categories = try await environment.categories.all(includeArchived: true)
            let now = environment.now()
            let builder = ReportBuilder(calendar: environment.calendar)
            let current = Period.month(containing: now, calendar: environment.calendar)
            let previous = Period.previousMonth(before: now, calendar: environment.calendar)

            state = .loaded(Content(
                points: builder.trend(rows, scale: scale, endingAt: now),
                comparisons: builder.comparison(rows, current: current, previous: previous),
                merchants: builder.topMerchants(rows, in: current),
                currentLabel: Self.shortMonth(current.start, calendar: environment.calendar),
                previousLabel: Self.shortMonth(previous.start, calendar: environment.calendar),
                categories: CategoryLookup(categories)))
        } catch {
            state = .empty
        }
    }

    static func shortMonth(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = TurkishLocale.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}
