import Core
import Foundation

/// İşlem listesinin gün başlığıyla gruplanmış hâli (D2).
public struct TransactionDayGroup: Hashable, Sendable, Identifiable {
    public let date: Date
    public let transactions: [TransactionEntity]

    public var id: Date { date }

    public init(date: Date, transactions: [TransactionEntity]) {
        self.date = date
        self.transactions = transactions
    }

    /// Gün toplamı gelir ve gideri kapsar; transfer günü şişirmemeli.
    public var total: Money {
        transactions.reduce(Money.zero) { $0 + $1.signedAmount }
    }
}

public struct TransactionService: Sendable {
    let transactions: any TransactionRepository
    let accounts: any AccountRepository
    let categories: any CategoryRepository
    let categoryRules: (any CategoryRuleRepository)?

    public init(
        transactions: any TransactionRepository,
        accounts: any AccountRepository,
        categories: any CategoryRepository,
        categoryRules: (any CategoryRuleRepository)? = nil
    ) {
        self.transactions = transactions
        self.accounts = accounts
        self.categories = categories
        self.categoryRules = categoryRules
    }

    public func list(_ query: TransactionQuery = .all) async throws -> [TransactionEntity] {
        try await transactions.transactions(matching: query)
    }

    public func grouped(
        _ query: TransactionQuery = .all,
        calendar: Calendar = .current
    ) async throws -> [TransactionDayGroup] {
        Self.group(try await list(query), calendar: calendar)
    }

    public static func group(
        _ rows: [TransactionEntity],
        calendar: Calendar = .current
    ) -> [TransactionDayGroup] {
        let buckets = Dictionary(grouping: rows) { calendar.startOfDay(for: $0.date) }
        return buckets
            .map { TransactionDayGroup(date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    public func save(_ transaction: TransactionEntity) async throws {
        try await transactions.save(transaction)
    }

    public func delete(id: UUID) async throws {
        try await transactions.delete(id: id)
    }

    public func summary(
        for interval: DateInterval,
        query: TransactionQuery = .all
    ) async throws -> PeriodSummary {
        var scoped = query
        scoped.dateRange = interval.start...interval.end
        return PeriodSummary.make(from: try await list(scoped))
    }

    public func breakdown(
        for interval: DateInterval,
        limit: Int = 8
    ) async throws -> [CategoryBreakdownItem] {
        var scoped = TransactionQuery.all
        scoped.dateRange = interval.start...interval.end
        return CategoryBreakdown.make(from: try await list(scoped), limit: limit)
    }

    public func netWorth() async throws -> Money {
        let accountList = try await accounts.all(includeArchived: true)
        let rows = try await transactions.transactions(matching: .all)
        return Balances.netWorth(accounts: accountList, transactions: rows)
    }

    /// İlk açılışta hesap tablosu boşsa "Nakit" yazılır.
    /// Hesapsız manuel giriş yapılamıyor; kullanıcı akışındaki hesap ekleme adımı
    /// gelene kadar defterin kullanılabilir kalması için gerekli.
    @discardableResult
    public func seedDefaultAccountIfNeeded() async throws -> Bool {
        guard try await accounts.all(includeArchived: true).isEmpty else { return false }
        try await accounts.save(AccountEntity(name: "Nakit", kind: .cash, sortIndex: 0))
        return true
    }

    /// İlk açılışta kategori tablosu boşsa varsayılanlar yazılır.
    @discardableResult
    public func seedDefaultCategoriesIfNeeded() async throws -> Bool {
        guard try await categories.all(includeArchived: true).isEmpty else { return false }
        let seeded = DefaultCategories.seed()
        for category in seeded {
            try await categories.save(category)
        }
        // Kategoriler yeni yazıldıysa varsayılan kurallar da onlara bağlanır.
        if let categoryRules, try await categoryRules.all().isEmpty {
            for rule in DefaultCategoryRules.seed(categories: seeded) {
                try await categoryRules.save(rule)
            }
        }
        return true
    }
}

public enum Period {
    /// "Ağustos 2026" gibi takvim ayının tamamı.
    public static func month(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start)!
        return DateInterval(start: start, end: end)
    }

    public static func previousMonth(before date: Date,
                                     calendar: Calendar = .current) -> DateInterval {
        let previous = calendar.date(byAdding: .month, value: -1, to: date)!
        return month(containing: previous, calendar: calendar)
    }

    /// "19 gün kaldı" — ayın kalan gün sayısı.
    public static func remainingDays(in interval: DateInterval, from date: Date,
                                     calendar: Calendar = .current) -> Int {
        let end = calendar.startOfDay(for: interval.end)
        let today = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: today, to: end).day ?? 0)
    }
}
