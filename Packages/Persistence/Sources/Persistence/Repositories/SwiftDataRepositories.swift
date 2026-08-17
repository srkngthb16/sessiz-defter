import Core
import Domain
import Foundation
import SwiftData

/// Tüm repository'ler tek bir ModelActor üzerinde çalışır: SwiftData ModelContext
/// iş parçacığına bağlıdır, ayrı context'ler arasında nesne taşımak veri yarışı üretir.
@ModelActor
public actor PersistenceStore {
    public nonisolated var accounts: AccountRepository { SwiftDataAccountRepository(store: self) }
    public nonisolated var categories: CategoryRepository { SwiftDataCategoryRepository(store: self) }
    public nonisolated var transactions: TransactionRepository { SwiftDataTransactionRepository(store: self) }
    public nonisolated var budgets: BudgetRepository { SwiftDataBudgetRepository(store: self) }
    public nonisolated var importBatches: ImportBatchRepository { SwiftDataImportBatchRepository(store: self) }
    public nonisolated var parserProfiles: ParserProfileRepository { SwiftDataParserProfileRepository(store: self) }
    public nonisolated var categoryRules: CategoryRuleRepository {
        SwiftDataCategoryRuleRepository(store: self)
    }
    public nonisolated var resetter: DataResetting { SwiftDataResetter(store: self) }

    /// Hesap toplamları. İşlem yazan her yol bunu düşürür; okuma yolu yeniden
    /// hesaplar. Actor içinde olduğu için eşzamanlılık sorunu yok.
    var signedTotalsCache: [UUID: Money]?

    func invalidateSignedTotals() { signedTotalsCache = nil }

    // MARK: Account

    func fetchAccounts(includeArchived: Bool) throws -> [AccountEntity] {
        let descriptor = FetchDescriptor<SDAccount>(
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor)
            .filter { includeArchived || !$0.isArchived }
            .map(\.entity)
    }

    func fetchAccount(id: UUID) throws -> AccountEntity? {
        try model(SDAccount.self, id: id)?.entity
    }

    func upsert(_ entity: AccountEntity) throws {
        if let existing = try model(SDAccount.self, id: entity.id) {
            existing.apply(entity)
        } else {
            modelContext.insert(SDAccount.make(entity))
        }
        try modelContext.save()
    }

    func deleteAccount(id: UUID) throws {
        if let existing = try model(SDAccount.self, id: id) { modelContext.delete(existing) }
        try modelContext.save()
    }

    // MARK: Category

    func fetchCategories(includeArchived: Bool) throws -> [CategoryEntity] {
        let descriptor = FetchDescriptor<SDCategory>(sortBy: [SortDescriptor(\.sortIndex)])
        return try modelContext.fetch(descriptor)
            .filter { includeArchived || !$0.isArchived }
            .map(\.entity)
    }

    func fetchCategory(id: UUID) throws -> CategoryEntity? {
        try model(SDCategory.self, id: id)?.entity
    }

    func upsert(_ entity: CategoryEntity) throws {
        if let existing = try model(SDCategory.self, id: entity.id) {
            existing.apply(entity)
        } else {
            modelContext.insert(SDCategory.make(entity))
        }
        try modelContext.save()
    }

    func deleteCategory(id: UUID) throws {
        if let existing = try model(SDCategory.self, id: id) { modelContext.delete(existing) }
        try modelContext.save()
    }

    // MARK: Transaction

    func fetchTransactions(matching query: TransactionQuery) throws -> [TransactionEntity] {
        // Tarih aralığı store tarafında süzülür (en seçici koşul); kalan alanlar
        // TransactionQuery.matches ile bellekte — filtre semantiği tek yerde kalsın diye.
        var descriptor = FetchDescriptor<SDTransaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse),
                     SortDescriptor(\.createdAt, order: .reverse)])
        let search = query.searchText.flatMap { $0.isEmpty ? nil : $0.trUpper }
        // Arama da store tarafında: 10.000 kaydı varlığa çevirip taramak 490 ms
        // sürüyordu. Aranan metin yazarken hazırlanan searchIndex sütununda.
        switch (query.dateRange, search) {
        case (let range?, let text?):
            let lower = range.lowerBound, upper = range.upperBound
            descriptor.predicate = #Predicate {
                $0.date >= lower && $0.date <= upper && $0.searchIndex.contains(text)
            }
        case (let range?, nil):
            let lower = range.lowerBound, upper = range.upperBound
            descriptor.predicate = #Predicate { $0.date >= lower && $0.date <= upper }
        case (nil, let text?):
            descriptor.predicate = #Predicate { $0.searchIndex.contains(text) }
        case (nil, nil):
            break
        }
        // Sınır yalnızca başka filtre kalmadığında store tarafında uygulanabilir;
        // yoksa elenecek satırlar sınırı doldurup sonucu eksiltir.
        var narrowed = query
        narrowed.dateRange = nil
        narrowed.searchText = nil
        if let limit = query.limit, narrowed.needsInMemoryFiltering == false {
            descriptor.fetchLimit = limit
        }
        let rows = try modelContext.fetch(descriptor).map(\.entity)
        return narrowed.apply(to: rows)
    }

    /// Arama sütunu sonradan eklendi; eski kayıtlarda boş kalıyor ve arama onları
    /// bulamıyor. Uygulama açılışında bir kez doldurulur, dolu defterde hiçbir şey
    /// yapmaz. Kaç satır düzeltildiğini döndürür.
    @discardableResult
    public func backfillSearchIndex() throws -> Int {
        // Yüklemle ("searchIndex boş olanlar") süzülmüyor: sütun sonradan
        // eklendiği için eski satırlarda değer boş dize değil NULL kalıyor ve
        // yüklem onları hiç görmüyordu — arama sessizce hiçbir şey bulmuyordu
        // (simülatörde yakalandı). Satırlar okunup gerçek değerle karşılaştırılıyor.
        var fixed = 0
        for row in try modelContext.fetch(FetchDescriptor<SDTransaction>()) {
            let expected = row.entity.searchIndexText
            guard row.searchIndex != expected else { continue }
            row.searchIndex = expected
            fixed += 1
        }
        guard fixed > 0 else { return 0 }
        try modelContext.save()
        return fixed
    }

    /// Yalnız test için: sütunun eklenmesinden önce yazılmış kayıtları taklit eder.
    /// Geri doldurmanın gerçekten çalıştığı başka türlü doğrulanamıyor.
    @discardableResult
    public func clearSearchIndexForTesting() throws -> Int {
        let rows = try modelContext.fetch(FetchDescriptor<SDTransaction>())
        for row in rows { row.searchIndex = "" }
        try modelContext.save()
        return rows.count
    }

    func fetchTransaction(id: UUID) throws -> TransactionEntity? {
        try model(SDTransaction.self, id: id)?.entity
    }

    func upsert(_ entity: TransactionEntity) throws {
        try insertOrUpdate(entity)
        try modelContext.save()
        invalidateSignedTotals()
    }

    /// İçe aktarma tek yazma işlemi: herhangi biri düşerse hiçbiri kalmaz.
    func upsertAll(_ entities: [TransactionEntity]) throws {
        do {
            // Kayıt başına "var mı" sorgusu atmak 10.000 satırda dakikalara
            // çıkıyordu (her sorgu büyüyen tabloyu tarıyor). Var olanlar tek
            // sorguyla alınıp sözlüğe konuyor.
            let ids = entities.map(\.id)
            let existing = try modelContext.fetch(
                FetchDescriptor<SDTransaction>(predicate: #Predicate { ids.contains($0.id) }))
            let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            for entity in entities {
                if let model = byID[entity.id] {
                    model.apply(entity)
                } else {
                    modelContext.insert(SDTransaction.make(entity))
                }
            }
            try modelContext.save()
            invalidateSignedTotals()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func insertOrUpdate(_ entity: TransactionEntity) throws {
        if let existing = try model(SDTransaction.self, id: entity.id) {
            existing.apply(entity)
        } else {
            modelContext.insert(SDTransaction.make(entity))
        }
    }

    func deleteTransaction(id: UUID) throws {
        if let existing = try model(SDTransaction.self, id: id) { modelContext.delete(existing) }
        try modelContext.save()
        invalidateSignedTotals()
    }

    func deleteAllTransactions() throws {
        try modelContext.delete(model: SDTransaction.self)
        try modelContext.save()
        invalidateSignedTotals()
    }

    /// Hesap başına toplam. Satırlar varlığa çevrilmiyor: yalnız üç alan okunuyor,
    /// dashboard açılışındaki 450 ms'nin çoğu varlık dönüşümündeydi.
    func signedTotalsByAccount() throws -> [UUID: Money] {
        // 10.000 satırı toplamak yarım saniye sürüyor ve sonuç yalnız yazma
        // olunca değişiyor. Sonuç actor içinde tutuluyor, her yazma düşürüyor:
        // sekme değiştirmek defteri baştan toplamasın.
        if let signedTotalsCache { return signedTotalsCache }
        let computed = try computeSignedTotalsByAccount()
        signedTotalsCache = computed
        return computed
    }

    private func computeSignedTotalsByAccount() throws -> [UUID: Money] {
        var totals: [UUID: Int] = [:]
        var currencies: [UUID: String] = [:]
        // Yalnız dört sütun okunuyor: tam satırı materyalize etmek 10.000 kayıtta
        // dashboard açılışını eşiğin üstüne çıkarıyordu.
        var descriptor = FetchDescriptor<SDTransaction>()
        descriptor.propertiesToFetch = [\.accountID, \.amountMinorUnits,
                                        \.directionRaw, \.currencyCode]
        for row in try modelContext.fetch(descriptor) {
            let direction = TransactionDirection(rawValue: row.directionRaw) ?? .expense
            let signed = switch direction {
            case .income: row.amountMinorUnits
            case .expense: -row.amountMinorUnits
            case .transfer: 0
            }
            totals[row.accountID, default: 0] += signed
            currencies[row.accountID] = row.currencyCode
        }
        return totals.reduce(into: [:]) { result, entry in
            result[entry.key] = Money(minorUnits: entry.value,
                                      currencyCode: currencies[entry.key] ?? "TRY")
        }
    }

    func countTransactions(inBatch id: UUID) throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.importBatchID == id }))
    }

    func duplicateHashes(among hashes: Set<String>) throws -> Set<String> {
        guard !hashes.isEmpty else { return [] }
        let list = Array(hashes)
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { list.contains($0.duplicateHash) })
        return Set(try modelContext.fetch(descriptor).map(\.duplicateHash))
    }

    func countTransactions(matching query: TransactionQuery) throws -> Int {
        // Yalnız tarihle süzülen sayım store tarafında yapılır: 10.000 kaydı
        // varlığa çevirip saymak 458 ms sürüyordu. Bellekte süzülen alan varsa
        // eski yol geçerli — filtre semantiği tek yerde kalmalı.
        guard query.needsInMemoryFiltering else {
            var descriptor = FetchDescriptor<SDTransaction>()
            if let range = query.dateRange {
                let lower = range.lowerBound, upper = range.upperBound
                descriptor.predicate = #Predicate { $0.date >= lower && $0.date <= upper }
            }
            let total = try modelContext.fetchCount(descriptor)
            return query.limit.map { min($0, total) } ?? total
        }
        return try fetchTransactions(matching: query).count
    }

    // MARK: Budget

    func fetchBudgets(includeArchived: Bool) throws -> [BudgetEntity] {
        let descriptor = FetchDescriptor<SDBudget>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        return try modelContext.fetch(descriptor)
            .filter { includeArchived || !$0.isArchived }
            .map(\.entity)
    }

    func fetchBudget(id: UUID) throws -> BudgetEntity? {
        try model(SDBudget.self, id: id)?.entity
    }

    func fetchBudget(categoryID: UUID) throws -> BudgetEntity? {
        let descriptor = FetchDescriptor<SDBudget>(
            predicate: #Predicate { $0.categoryID == categoryID && !$0.isArchived })
        return try modelContext.fetch(descriptor).first?.entity
    }

    func upsert(_ entity: BudgetEntity) throws {
        if let existing = try model(SDBudget.self, id: entity.id) {
            existing.apply(entity)
        } else {
            modelContext.insert(SDBudget.make(entity))
        }
        try modelContext.save()
    }

    func deleteBudget(id: UUID) throws {
        if let existing = try model(SDBudget.self, id: id) { modelContext.delete(existing) }
        try modelContext.save()
    }

    // MARK: ImportBatch

    func fetchBatches() throws -> [ImportBatchEntity] {
        let descriptor = FetchDescriptor<SDImportBatch>(
            sortBy: [SortDescriptor(\.importedAt, order: .reverse)])
        return try modelContext.fetch(descriptor).map(\.entity)
    }

    func fetchBatch(id: UUID) throws -> ImportBatchEntity? {
        try model(SDImportBatch.self, id: id)?.entity
    }

    func upsert(_ entity: ImportBatchEntity) throws {
        if let existing = try model(SDImportBatch.self, id: entity.id) {
            existing.apply(entity)
        } else {
            modelContext.insert(SDImportBatch.make(entity))
        }
        try modelContext.save()
    }

    func deleteBatch(id: UUID) throws {
        if let existing = try model(SDImportBatch.self, id: id) { modelContext.delete(existing) }
        try modelContext.save()
    }

    // MARK: ParserProfile

    func fetchProfiles() throws -> [ParserProfileEntity] {
        let descriptor = FetchDescriptor<SDParserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map(\.entity)
    }

    func fetchProfile(formatIdentifier: String) throws -> ParserProfileEntity? {
        let descriptor = FetchDescriptor<SDParserProfile>(
            predicate: #Predicate { $0.formatIdentifier == formatIdentifier })
        return try modelContext.fetch(descriptor).first?.entity
    }

    func upsert(_ entity: ParserProfileEntity) throws {
        if let existing = try model(SDParserProfile.self, id: entity.id) {
            existing.apply(entity)
        } else {
            modelContext.insert(SDParserProfile.make(entity))
        }
        try modelContext.save()
    }

    func deleteProfile(id: UUID) throws {
        if let existing = try model(SDParserProfile.self, id: id) { modelContext.delete(existing) }
        try modelContext.save()
    }

    // MARK: CategoryRule

    func fetchRules() throws -> [CategoryRuleEntity] {
        let descriptor = FetchDescriptor<SDCategoryRule>(sortBy: [SortDescriptor(\.createdAt)])
        return try modelContext.fetch(descriptor).map(\.entity)
    }

    func upsert(_ entity: CategoryRuleEntity) throws {
        if let existing = try model(SDCategoryRule.self, id: entity.id) {
            existing.apply(entity)
        } else {
            modelContext.insert(SDCategoryRule.make(entity))
        }
        try modelContext.save()
    }

    func deleteRule(id: UUID) throws {
        if let existing = try model(SDCategoryRule.self, id: id) { modelContext.delete(existing) }
        try modelContext.save()
    }

    // MARK: Hepsini sil

    func deleteEverything() throws {
        try modelContext.delete(model: SDCategoryRule.self)
        try modelContext.delete(model: SDTransaction.self)
        try modelContext.delete(model: SDBudget.self)
        try modelContext.delete(model: SDImportBatch.self)
        try modelContext.delete(model: SDParserProfile.self)
        try modelContext.delete(model: SDCategory.self)
        try modelContext.delete(model: SDAccount.self)
        try modelContext.save()
        invalidateSignedTotals()
    }

    private func model<T: PersistentModel>(_ type: T.Type, id: UUID) throws -> T? {
        switch type {
        case is SDAccount.Type:
            return try modelContext.fetch(
                FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })).first as? T
        case is SDCategory.Type:
            return try modelContext.fetch(
                FetchDescriptor<SDCategory>(predicate: #Predicate { $0.id == id })).first as? T
        case is SDTransaction.Type:
            return try modelContext.fetch(
                FetchDescriptor<SDTransaction>(predicate: #Predicate { $0.id == id })).first as? T
        case is SDBudget.Type:
            return try modelContext.fetch(
                FetchDescriptor<SDBudget>(predicate: #Predicate { $0.id == id })).first as? T
        case is SDImportBatch.Type:
            return try modelContext.fetch(
                FetchDescriptor<SDImportBatch>(predicate: #Predicate { $0.id == id })).first as? T
        case is SDParserProfile.Type:
            return try modelContext.fetch(
                FetchDescriptor<SDParserProfile>(predicate: #Predicate { $0.id == id })).first as? T
        case is SDCategoryRule.Type:
            return try modelContext.fetch(
                FetchDescriptor<SDCategoryRule>(predicate: #Predicate { $0.id == id })).first as? T
        default:
            return nil
        }
    }
}

// MARK: - Protokol köprüleri

struct SwiftDataAccountRepository: AccountRepository {
    let store: PersistenceStore
    func all(includeArchived: Bool) async throws -> [AccountEntity] {
        try await store.fetchAccounts(includeArchived: includeArchived)
    }
    func account(id: UUID) async throws -> AccountEntity? { try await store.fetchAccount(id: id) }
    func save(_ account: AccountEntity) async throws { try await store.upsert(account) }
    func delete(id: UUID) async throws { try await store.deleteAccount(id: id) }
}

struct SwiftDataCategoryRepository: CategoryRepository {
    let store: PersistenceStore
    func all(includeArchived: Bool) async throws -> [CategoryEntity] {
        try await store.fetchCategories(includeArchived: includeArchived)
    }
    func category(id: UUID) async throws -> CategoryEntity? { try await store.fetchCategory(id: id) }
    func save(_ category: CategoryEntity) async throws { try await store.upsert(category) }
    func delete(id: UUID) async throws { try await store.deleteCategory(id: id) }
}

struct SwiftDataTransactionRepository: TransactionRepository {
    let store: PersistenceStore
    func transactions(matching query: TransactionQuery) async throws -> [TransactionEntity] {
        try await store.fetchTransactions(matching: query)
    }
    func transaction(id: UUID) async throws -> TransactionEntity? {
        try await store.fetchTransaction(id: id)
    }
    func save(_ transaction: TransactionEntity) async throws { try await store.upsert(transaction) }
    func saveAll(_ transactions: [TransactionEntity]) async throws {
        try await store.upsertAll(transactions)
    }
    func delete(id: UUID) async throws { try await store.deleteTransaction(id: id) }
    func deleteAll() async throws { try await store.deleteAllTransactions() }
    func signedTotalsByAccount() async throws -> [UUID: Money] {
        try await store.signedTotalsByAccount()
    }
    func count(inBatch id: UUID) async throws -> Int {
        try await store.countTransactions(inBatch: id)
    }
    func existingDuplicateHashes(among hashes: Set<String>) async throws -> Set<String> {
        try await store.duplicateHashes(among: hashes)
    }
    func count(matching query: TransactionQuery) async throws -> Int {
        try await store.countTransactions(matching: query)
    }
}

struct SwiftDataBudgetRepository: BudgetRepository {
    let store: PersistenceStore
    func all(includeArchived: Bool) async throws -> [BudgetEntity] {
        try await store.fetchBudgets(includeArchived: includeArchived)
    }
    func budget(id: UUID) async throws -> BudgetEntity? { try await store.fetchBudget(id: id) }
    func budget(categoryID: UUID) async throws -> BudgetEntity? {
        try await store.fetchBudget(categoryID: categoryID)
    }
    func save(_ budget: BudgetEntity) async throws { try await store.upsert(budget) }
    func delete(id: UUID) async throws { try await store.deleteBudget(id: id) }
}

struct SwiftDataImportBatchRepository: ImportBatchRepository {
    let store: PersistenceStore
    func all() async throws -> [ImportBatchEntity] { try await store.fetchBatches() }
    func batch(id: UUID) async throws -> ImportBatchEntity? { try await store.fetchBatch(id: id) }
    func save(_ batch: ImportBatchEntity) async throws { try await store.upsert(batch) }
    func delete(id: UUID) async throws { try await store.deleteBatch(id: id) }
}

struct SwiftDataParserProfileRepository: ParserProfileRepository {
    let store: PersistenceStore
    func all() async throws -> [ParserProfileEntity] { try await store.fetchProfiles() }
    func profile(formatIdentifier: String) async throws -> ParserProfileEntity? {
        try await store.fetchProfile(formatIdentifier: formatIdentifier)
    }
    func save(_ profile: ParserProfileEntity) async throws { try await store.upsert(profile) }
    func delete(id: UUID) async throws { try await store.deleteProfile(id: id) }
}

struct SwiftDataCategoryRuleRepository: CategoryRuleRepository {
    let store: PersistenceStore
    func all() async throws -> [CategoryRuleEntity] { try await store.fetchRules() }
    func save(_ rule: CategoryRuleEntity) async throws { try await store.upsert(rule) }
    func delete(id: UUID) async throws { try await store.deleteRule(id: id) }
}

struct SwiftDataResetter: DataResetting {
    let store: PersistenceStore
    func deleteEverything() async throws { try await store.deleteEverything() }
}
