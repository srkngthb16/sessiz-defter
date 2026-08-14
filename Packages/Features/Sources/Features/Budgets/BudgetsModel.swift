import Core
import Domain
import Foundation

@Observable
@MainActor
public final class BudgetsModel {
    public struct Content: Sendable {
        public var statuses: [BudgetStatus]
        public var overview: BudgetEngine.Overview
        public var periodTitle: String
        public var daysRemaining: Int
        public var categories: CategoryLookup
    }

    public enum State {
        case loading
        case empty
        case loaded(Content)
    }

    public private(set) var state: State = .loading
    private let environment: AppEnvironment
    private let notifier: (any BudgetNotifying)?
    private let planner = BudgetNotificationPlanner()

    public init(environment: AppEnvironment, notifier: (any BudgetNotifying)? = nil) {
        self.environment = environment
        self.notifier = notifier
    }

    public func load() async {
        do {
            let budgets = try await environment.budgets.all(includeArchived: false)
            guard !budgets.isEmpty else {
                state = .empty
                return
            }
            let categories = try await environment.categories.all(includeArchived: true)
            let now = environment.now()
            let period = Period.month(containing: now, calendar: environment.calendar)
            let rows = try await environment.transactions.transactions(
                matching: TransactionQuery(dateRange: period.start...period.end))

            let engine = BudgetEngine(calendar: environment.calendar)
            let statuses = engine.statuses(budgets: budgets, transactions: rows,
                                           period: period, now: now)
            let daysRemaining = Period.remainingDays(in: period, from: now,
                                                     calendar: environment.calendar)
            state = .loaded(Content(
                statuses: statuses,
                overview: engine.overview(statuses, daysRemaining: daysRemaining),
                periodTitle: DashboardModel.monthTitle(period.start,
                                                       calendar: environment.calendar),
                daysRemaining: daysRemaining,
                categories: CategoryLookup(categories)))
            await notifyIfNeeded(statuses: statuses, categories: CategoryLookup(categories),
                                 periodStart: period.start)
        } catch {
            state = .empty
        }
    }

    /// Eşiği geçen bütçeler için yerel bildirim. Aynı bütçe, dönem ve eşik için
    /// yalnızca bir kez gönderilir.
    private func notifyIfNeeded(statuses: [BudgetStatus], categories: CategoryLookup,
                                periodStart: Date) async {
        guard let notifier else { return }
        let pending = await notifier.pendingIdentifiers()
        let requests = planner.requests(for: statuses, categories: categories,
                                        periodStart: periodStart, alreadyScheduled: pending)
        guard !requests.isEmpty, await notifier.requestAuthorizationIfNeeded() else { return }
        await notifier.schedule(requests)
    }

    public func delete(_ status: BudgetStatus) async {
        try? await environment.budgets.delete(id: status.budget.id)
        await load()
    }
}

@Observable
@MainActor
public final class BudgetEditorModel {
    public var limitText: String
    public var categoryID: UUID?
    public var warnsAtEightyPercent: Bool
    public var rollsOver: Bool
    public private(set) var categories = CategoryLookup()
    public private(set) var averageHint: String?
    public private(set) var suggestions: [Money] = []

    let existing: BudgetEntity?
    private let environment: AppEnvironment

    public init(environment: AppEnvironment, editing existing: BudgetEntity? = nil) {
        self.environment = environment
        self.existing = existing
        limitText = existing.map { Fmt.amount($0.limit) } ?? ""
        categoryID = existing?.categoryID
        warnsAtEightyPercent = existing?.warnsAtEightyPercent ?? true
        rollsOver = existing?.rollsOver ?? false
    }

    public var parsedLimit: Money? {
        TransactionEditorView.parseAmount(limitText)
    }

    public var canSave: Bool {
        categoryID != nil && (parsedLimit?.minorUnits ?? 0) > 0
    }

    public func load() async {
        categories = CategoryLookup(
            (try? await environment.categories.all(includeArchived: false)) ?? [])
        if categoryID == nil { categoryID = categories.expenseCategories.first?.id }
        await refreshHint()
    }

    /// E2 — "Son 3 ayın Eğlence ortalaması 3.240 ₺. Yeni limit ortalamanın %8 üzerinde."
    public func refreshHint() async {
        guard let categoryID else {
            averageHint = nil
            suggestions = []
            return
        }
        let rows = (try? await environment.transactions.transactions(matching: .all)) ?? []
        let engine = BudgetEngine(calendar: environment.calendar)
        guard let average = engine.averageSpending(categoryID: categoryID,
                                                   transactions: rows,
                                                   endingBefore: environment.now()) else {
            averageHint = nil
            suggestions = []
            return
        }

        let name = categories.name(categoryID)
        var text = "Son 3 ayın \(name) ortalaması \(Fmt.amount(average)) ₺."
        if let limit = parsedLimit, average.minorUnits > 0 {
            let difference = Double(limit.minorUnits - average.minorUnits)
                / Double(average.minorUnits)
            let direction = difference >= 0 ? "üzerinde" : "altında"
            text += " Yeni limit ortalamanın \(Fmt.percent(abs(difference))) \(direction)."
        }
        averageHint = text
        // Ortalamanın çevresinde yuvarlak öneriler.
        let base = max(average.minorUnits, 10_000)
        suggestions = [0.8, 1.0, 1.15, 1.3].map { factor in
            Money(minorUnits: Int((Double(base) * factor / 10_000).rounded()) * 10_000)
        }
    }

    public func save() async {
        guard let categoryID, let parsedLimit else { return }
        let period = Period.month(containing: environment.now(), calendar: environment.calendar)
        let entity = BudgetEntity(
            id: existing?.id ?? UUID(),
            categoryID: categoryID,
            limit: parsedLimit,
            warnsAtEightyPercent: warnsAtEightyPercent,
            rollsOver: rollsOver,
            startDate: existing?.startDate ?? period.start)
        try? await environment.budgets.save(entity)
    }
}
