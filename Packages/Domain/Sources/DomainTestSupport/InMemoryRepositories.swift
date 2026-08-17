import Core
import Domain
import Foundation

/// Bellek içi gerçeklemeler. SwiftData'ya dokunmadan Domain ve ImportPipeline
/// testlerini çalıştırmak için var; üretim kodunda kullanılmaz.
public actor InMemoryStore {
    public private(set) var accounts: [UUID: AccountEntity] = [:]
    public private(set) var categories: [UUID: CategoryEntity] = [:]
    public private(set) var transactions: [UUID: TransactionEntity] = [:]
    public private(set) var budgets: [UUID: BudgetEntity] = [:]
    public private(set) var batches: [UUID: ImportBatchEntity] = [:]
    public private(set) var profiles: [UUID: ParserProfileEntity] = [:]
    public private(set) var rules: [UUID: CategoryRuleEntity] = [:]

    public init() {}

    public func seed(
        accounts: [AccountEntity] = [],
        categories: [CategoryEntity] = [],
        transactions: [TransactionEntity] = [],
        budgets: [BudgetEntity] = []
    ) {
        for item in accounts { self.accounts[item.id] = item }
        for item in categories { self.categories[item.id] = item }
        for item in transactions { self.transactions[item.id] = item }
        for item in budgets { self.budgets[item.id] = item }
    }

    func put(_ item: AccountEntity) { accounts[item.id] = item }
    func put(_ item: CategoryEntity) { categories[item.id] = item }
    func put(_ item: TransactionEntity) { transactions[item.id] = item }
    func put(_ item: BudgetEntity) { budgets[item.id] = item }
    func put(_ item: ImportBatchEntity) { batches[item.id] = item }
    func put(_ item: ParserProfileEntity) { profiles[item.id] = item }
    func put(_ item: CategoryRuleEntity) { rules[item.id] = item }

    func removeAccount(_ id: UUID) { accounts[id] = nil }
    func removeCategory(_ id: UUID) { categories[id] = nil }
    func removeTransaction(_ id: UUID) { transactions[id] = nil }
    func removeBudget(_ id: UUID) { budgets[id] = nil }
    func removeBatch(_ id: UUID) { batches[id] = nil }
    func removeProfile(_ id: UUID) { profiles[id] = nil }
    func removeRule(_ id: UUID) { rules[id] = nil }

    func removeAllTransactions() { transactions.removeAll() }

    func removeEverything() {
        accounts.removeAll(); categories.removeAll(); transactions.removeAll()
        budgets.removeAll(); batches.removeAll(); profiles.removeAll(); rules.removeAll()
    }
}

public struct InMemoryAccountRepository: AccountRepository {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }

    public func all(includeArchived: Bool) async throws -> [AccountEntity] {
        await store.accounts.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
    public func account(id: UUID) async throws -> AccountEntity? { await store.accounts[id] }
    public func save(_ account: AccountEntity) async throws { await store.put(account) }
    public func delete(id: UUID) async throws { await store.removeAccount(id) }
}

public struct InMemoryCategoryRepository: CategoryRepository {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }

    public func all(includeArchived: Bool) async throws -> [CategoryEntity] {
        await store.categories.values
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
    public func category(id: UUID) async throws -> CategoryEntity? { await store.categories[id] }
    public func save(_ category: CategoryEntity) async throws { await store.put(category) }
    public func delete(id: UUID) async throws { await store.removeCategory(id) }
}

public struct InMemoryTransactionRepository: TransactionRepository {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }

    public func signedTotalsByAccount() async throws -> [UUID: Money] {
        await store.transactions.values.reduce(into: [:]) { result, transaction in
            let current = result[transaction.accountID]
                ?? Money(minorUnits: 0, currencyCode: transaction.amount.currencyCode)
            result[transaction.accountID] = current + transaction.signedAmount
        }
    }

    public func count(inBatch id: UUID) async throws -> Int {
        await store.transactions.values.filter { $0.importBatchID == id }.count
    }

    public func transactions(matching query: TransactionQuery) async throws -> [TransactionEntity] {
        query.apply(to: Array(await store.transactions.values))
    }
    public func transaction(id: UUID) async throws -> TransactionEntity? {
        await store.transactions[id]
    }
    public func save(_ transaction: TransactionEntity) async throws {
        await store.put(transaction)
    }
    public func saveAll(_ transactions: [TransactionEntity]) async throws {
        for transaction in transactions { await store.put(transaction) }
    }
    public func delete(id: UUID) async throws { await store.removeTransaction(id) }
    public func deleteAll() async throws { await store.removeAllTransactions() }

    public func existingDuplicateHashes(among hashes: Set<String>) async throws -> Set<String> {
        let known = Set(await store.transactions.values.map(\.duplicateHash))
        return hashes.intersection(known)
    }

    public func count(matching query: TransactionQuery) async throws -> Int {
        try await transactions(matching: query).count
    }
}

public struct InMemoryBudgetRepository: BudgetRepository {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }

    public func all(includeArchived: Bool) async throws -> [BudgetEntity] {
        await store.budgets.values.filter { includeArchived || !$0.isArchived }
            .sorted { $0.startDate > $1.startDate }
    }
    public func budget(id: UUID) async throws -> BudgetEntity? { await store.budgets[id] }
    public func budget(categoryID: UUID) async throws -> BudgetEntity? {
        await store.budgets.values.first { $0.categoryID == categoryID && !$0.isArchived }
    }
    public func save(_ budget: BudgetEntity) async throws { await store.put(budget) }
    public func delete(id: UUID) async throws { await store.removeBudget(id) }
}

public struct InMemoryImportBatchRepository: ImportBatchRepository {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }

    public func all() async throws -> [ImportBatchEntity] {
        await store.batches.values.sorted { $0.importedAt > $1.importedAt }
    }
    public func batch(id: UUID) async throws -> ImportBatchEntity? { await store.batches[id] }
    public func save(_ batch: ImportBatchEntity) async throws { await store.put(batch) }
    public func delete(id: UUID) async throws { await store.removeBatch(id) }
}

public struct InMemoryParserProfileRepository: ParserProfileRepository {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }

    public func all() async throws -> [ParserProfileEntity] {
        await store.profiles.values.sorted { $0.createdAt < $1.createdAt }
    }
    public func profile(formatIdentifier: String) async throws -> ParserProfileEntity? {
        await store.profiles.values.first { $0.formatIdentifier == formatIdentifier }
    }
    public func save(_ profile: ParserProfileEntity) async throws { await store.put(profile) }
    public func delete(id: UUID) async throws { await store.removeProfile(id) }
}

public struct InMemoryCategoryRuleRepository: CategoryRuleRepository {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }

    public func all() async throws -> [CategoryRuleEntity] {
        await store.rules.values.sorted { $0.createdAt < $1.createdAt }
    }
    public func save(_ rule: CategoryRuleEntity) async throws { await store.put(rule) }
    public func delete(id: UUID) async throws { await store.removeRule(id) }
}

public struct InMemoryDataResetter: DataResetting {
    let store: InMemoryStore
    public init(store: InMemoryStore) { self.store = store }
    public func deleteEverything() async throws { await store.removeEverything() }
}
