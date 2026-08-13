import Core
import Foundation

/// Domain yalnızca bu protokolleri bilir. Gerçeklemeler Persistence hedefindedir;
/// testlerde in-memory gerçeklemeler kullanılır.
public protocol AccountRepository: Sendable {
    func all(includeArchived: Bool) async throws -> [AccountEntity]
    func account(id: UUID) async throws -> AccountEntity?
    func save(_ account: AccountEntity) async throws
    func delete(id: UUID) async throws
}

public protocol CategoryRepository: Sendable {
    func all(includeArchived: Bool) async throws -> [CategoryEntity]
    func category(id: UUID) async throws -> CategoryEntity?
    func save(_ category: CategoryEntity) async throws
    func delete(id: UUID) async throws
}

/// İşlem sorgusu tek bir yapı üzerinden geçer: filtre sheet'i (D4), arama (D2) ve
/// raporlar (E3) aynı yolu kullanır, böylece davranış tek yerde test edilir.
public struct TransactionQuery: Hashable, Sendable {
    public var searchText: String?
    public var dateRange: ClosedRange<Date>?
    public var categoryIDs: Set<UUID>
    public var accountIDs: Set<UUID>
    public var directions: Set<TransactionDirection>
    public var minimumAmount: Money?
    public var maximumAmount: Money?
    public var onlyNeedsReview: Bool
    public var limit: Int?

    public init(
        searchText: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        categoryIDs: Set<UUID> = [],
        accountIDs: Set<UUID> = [],
        directions: Set<TransactionDirection> = [],
        minimumAmount: Money? = nil,
        maximumAmount: Money? = nil,
        onlyNeedsReview: Bool = false,
        limit: Int? = nil
    ) {
        self.searchText = searchText
        self.dateRange = dateRange
        self.categoryIDs = categoryIDs
        self.accountIDs = accountIDs
        self.directions = directions
        self.minimumAmount = minimumAmount
        self.maximumAmount = maximumAmount
        self.onlyNeedsReview = onlyNeedsReview
        self.limit = limit
    }

    public static let all = TransactionQuery()
}

public protocol TransactionRepository: Sendable {
    /// Tarihe göre azalan sırada döner.
    func transactions(matching query: TransactionQuery) async throws -> [TransactionEntity]
    func transaction(id: UUID) async throws -> TransactionEntity?
    func save(_ transaction: TransactionEntity) async throws
    /// İçe aktarma tek yazma işlemidir: biri düşerse hiçbiri yazılmaz.
    func saveAll(_ transactions: [TransactionEntity]) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
    /// Verilen hash'lerden hangileri zaten kayıtlı.
    func existingDuplicateHashes(among hashes: Set<String>) async throws -> Set<String>
    func count(matching query: TransactionQuery) async throws -> Int
}

public protocol BudgetRepository: Sendable {
    func all(includeArchived: Bool) async throws -> [BudgetEntity]
    func budget(id: UUID) async throws -> BudgetEntity?
    func budget(categoryID: UUID) async throws -> BudgetEntity?
    func save(_ budget: BudgetEntity) async throws
    func delete(id: UUID) async throws
}

public protocol ImportBatchRepository: Sendable {
    func all() async throws -> [ImportBatchEntity]
    func batch(id: UUID) async throws -> ImportBatchEntity?
    func save(_ batch: ImportBatchEntity) async throws
    func delete(id: UUID) async throws
}

public protocol ParserProfileRepository: Sendable {
    func all() async throws -> [ParserProfileEntity]
    func profile(formatIdentifier: String) async throws -> ParserProfileEntity?
    func save(_ profile: ParserProfileEntity) async throws
    func delete(id: UUID) async throws
}

/// Tüm veriyi silme (F3) tek yerden geçer.
public protocol DataResetting: Sendable {
    func deleteEverything() async throws
}
