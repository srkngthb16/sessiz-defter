import Core
import Domain
import Foundation
import SwiftData
import Testing
@testable import Persistence

@Suite("SwiftData kalıcılığı")
struct PersistenceStoreTests {
    static func date(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
    }

    func makeStore() throws -> PersistenceStore {
        PersistenceStore(modelContainer: try StoreFactory.makeInMemoryContainer())
    }

    @Test("Hesap yaz-oku-güncelle-sil")
    func hesapCRUD() async throws {
        let store = try makeStore()
        let repository = store.accounts
        let account = AccountEntity(name: "Ziraat", kind: .checking,
                                    openingBalance: Money(minorUnits: 1_000_00),
                                    maskedNumber: "••3412")
        try await repository.save(account)

        let loaded = try await repository.account(id: account.id)
        #expect(loaded?.name == "Ziraat")
        #expect(loaded?.openingBalance.minorUnits == 100_000)
        #expect(loaded?.maskedNumber == "••3412")

        var renamed = account
        renamed.name = "Ziraat Vadesiz"
        try await repository.save(renamed)
        #expect(try await repository.all(includeArchived: true).count == 1)
        #expect(try await repository.account(id: account.id)?.name == "Ziraat Vadesiz")

        try await repository.delete(id: account.id)
        #expect(try await repository.all(includeArchived: true).isEmpty)
    }

    @Test("İşlem alanları kayıp olmadan geri döner")
    func islemDonusumu() async throws {
        let store = try makeStore()
        let accountID = UUID(), categoryID = UUID(), batchID = UUID()
        let entity = TransactionEntity(
            date: Self.date(12), amount: Money(minorUnits: 84260), direction: .expense,
            detail: "Migros Ataşehir", categoryID: categoryID, accountID: accountID,
            note: "Haftalık market · indirimli", tags: ["ev", "indirim"],
            source: .statement, importBatchID: batchID, statementLineNumber: 18,
            categoryConfidence: 0.94, needsReview: false)
        try await store.transactions.save(entity)

        let loaded = try #require(try await store.transactions.transaction(id: entity.id))
        #expect(loaded.amount.minorUnits == 84260)
        #expect(loaded.direction == .expense)
        #expect(loaded.tags == ["ev", "indirim"])
        #expect(loaded.source == .statement)
        #expect(loaded.statementLineNumber == 18)
        #expect(loaded.categoryConfidence == 0.94)
        #expect(loaded.duplicateHash == entity.duplicateHash)
        #expect(loaded.note == "Haftalık market · indirimli")
    }

    @Test("Tarih aralığı store tarafında, kalan filtreler bellekte — sonuç aynı")
    func sorgu() async throws {
        let store = try makeStore()
        let accountID = UUID(), categoryID = UUID()
        try await store.transactions.saveAll([
            TransactionEntity(date: Self.date(12), amount: Money(minorUnits: 84260),
                              direction: .expense, detail: "Migros Ataşehir",
                              categoryID: categoryID, accountID: accountID),
            TransactionEntity(date: Self.date(11), amount: Money(minorUnits: 118000),
                              direction: .expense, detail: "Shell Otoyol",
                              accountID: accountID),
            TransactionEntity(date: Self.date(3), amount: Money(minorUnits: 5999),
                              direction: .expense, detail: "Spotify", accountID: accountID)
        ])

        let inRange = try await store.transactions.transactions(
            matching: TransactionQuery(dateRange: Self.date(10)...Self.date(13)))
        #expect(inRange.map(\.detail) == ["Migros Ataşehir", "Shell Otoyol"])

        let byCategory = try await store.transactions.transactions(
            matching: TransactionQuery(categoryIDs: [categoryID]))
        #expect(byCategory.count == 1)

        #expect(try await store.transactions.count(matching: .all) == 3)
    }

    @Test("Mükerrer hash sorgusu yalnızca kayıtlıları döner")
    func mukerrerSorgusu() async throws {
        let store = try makeStore()
        let entity = TransactionEntity(date: Self.date(12), amount: Money(minorUnits: 84260),
                                       direction: .expense, detail: "Migros",
                                       accountID: UUID())
        try await store.transactions.save(entity)

        let found = try await store.transactions.existingDuplicateHashes(
            among: [entity.duplicateHash, "yok-boyle-bir-hash"])
        #expect(found == [entity.duplicateHash])
    }

    @Test("saveAll aynı id'yi tekrar yazınca çoğaltmaz")
    func topluYazmaIdempotent() async throws {
        let store = try makeStore()
        let entity = TransactionEntity(date: Self.date(12), amount: Money(minorUnits: 100),
                                       direction: .expense, detail: "Test", accountID: UUID())
        try await store.transactions.saveAll([entity, entity])
        try await store.transactions.saveAll([entity])
        #expect(try await store.transactions.count(matching: .all) == 1)
    }

    @Test("Bütçe kategoriye göre bulunur, arşivli olan dönmez")
    func butce() async throws {
        let store = try makeStore()
        let categoryID = UUID()
        let budget = BudgetEntity(categoryID: categoryID, limit: Money(minorUnits: 260000),
                                  startDate: Self.date(1))
        try await store.budgets.save(budget)
        #expect(try await store.budgets.budget(categoryID: categoryID)?.limit.minorUnits == 260000)

        var archived = budget
        archived.isArchived = true
        try await store.budgets.save(archived)
        #expect(try await store.budgets.budget(categoryID: categoryID) == nil)
        #expect(try await store.budgets.all(includeArchived: false).isEmpty)
        #expect(try await store.budgets.all(includeArchived: true).count == 1)
    }

    @Test("Parser profili format kimliğiyle bulunur")
    func parserProfili() async throws {
        let store = try makeStore()
        let profile = ParserProfileEntity(
            bankName: "Ziraat Bankası", formatIdentifier: "ziraat.vadesiz.v1",
            signatures: ["T.C. ZİRAAT BANKASI", "HESAP ÖZETİ"],
            columnMapping: [.date, .detail, .amount, .balance])
        try await store.parserProfiles.save(profile)

        let loaded = try #require(
            try await store.parserProfiles.profile(formatIdentifier: "ziraat.vadesiz.v1"))
        #expect(loaded.bankName == "Ziraat Bankası")
        #expect(loaded.columnMapping == [.date, .detail, .amount, .balance])
        #expect(loaded.signatures.count == 2)
    }

    @Test("İçe aktarma özeti tüm sayaçlarıyla saklanır")
    func importBatch() async throws {
        let store = try makeStore()
        let batch = ImportBatchEntity(
            fileName: "Ziraat_ekstre_agustos.pdf", periodStart: Self.date(1),
            periodEnd: Self.date(12), addedCount: 44, skippedDuplicateCount: 2,
            manuallyRecategorizedCount: 3, bankFormatIdentifier: "ziraat.vadesiz.v1",
            sourceFileRetained: false, usedOCR: false)
        try await store.importBatches.save(batch)

        let loaded = try #require(try await store.importBatches.batch(id: batch.id))
        #expect(loaded.addedCount == 44)
        #expect(loaded.skippedDuplicateCount == 2)
        #expect(loaded.manuallyRecategorizedCount == 3)
        #expect(loaded.sourceFileRetained == false)
    }

    @Test("Kategori kuralı yazılır ve silinir")
    func kategoriKurali() async throws {
        let store = try makeStore()
        let categoryID = UUID()
        let rule = CategoryRuleEntity(keyword: "MIGROS", categoryID: categoryID,
                                      direction: .expense)
        try await store.categoryRules.save(rule)

        let loaded = try #require(try await store.categoryRules.all().first)
        #expect(loaded.keyword == "MIGROS")
        #expect(loaded.direction == .expense)
        #expect(loaded.isUserDefined)

        try await store.categoryRules.delete(id: rule.id)
        #expect(try await store.categoryRules.all().isEmpty)
    }

    @Test("deleteEverything her tabloyu boşaltır")
    func hepsiniSil() async throws {
        let store = try makeStore()
        let accountID = UUID(), categoryID = UUID()
        try await store.accounts.save(AccountEntity(name: "Nakit", kind: .cash))
        try await store.categories.save(
            CategoryEntity(id: categoryID, name: "Market", colorIndex: 0, symbolName: "cart"))
        try await store.transactions.save(TransactionEntity(
            date: Self.date(12), amount: Money(minorUnits: 100), direction: .expense,
            detail: "X", accountID: accountID))
        try await store.budgets.save(BudgetEntity(
            categoryID: categoryID, limit: Money(minorUnits: 1000), startDate: Self.date(1)))
        try await store.importBatches.save(ImportBatchEntity(fileName: "a.pdf"))
        try await store.parserProfiles.save(
            ParserProfileEntity(bankName: "X", formatIdentifier: "x.v1"))
        try await store.categoryRules.save(
            CategoryRuleEntity(keyword: "K", categoryID: categoryID))

        try await store.resetter.deleteEverything()

        #expect(try await store.transactions.count(matching: .all) == 0)
        #expect(try await store.accounts.all(includeArchived: true).isEmpty)
        #expect(try await store.categories.all(includeArchived: true).isEmpty)
        #expect(try await store.budgets.all(includeArchived: true).isEmpty)
        #expect(try await store.importBatches.all().isEmpty)
        #expect(try await store.parserProfiles.all().isEmpty)
        #expect(try await store.categoryRules.all().isEmpty)
    }
}
