import Core
import Domain
import Foundation
import Testing
@testable import Persistence

@Suite("Yedek alma ve geri yükleme")
struct BackupServiceTests {
    static func date(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
    }

    func makeStore() throws -> PersistenceStore {
        PersistenceStore(modelContainer: try StoreFactory.makeInMemoryContainer())
    }

    func seed(_ store: PersistenceStore) async throws -> (UUID, UUID) {
        let account = AccountEntity(name: "Ziraat", kind: .checking, maskedNumber: "••3412")
        let category = CategoryEntity(name: "Market", colorIndex: 0, symbolName: "cart")
        try await store.accounts.save(account)
        try await store.categories.save(category)
        try await store.budgets.save(BudgetEntity(categoryID: category.id,
                                                  limit: Money(minorUnits: 1_200_000),
                                                  startDate: Self.date(1)))
        try await store.importBatches.save(ImportBatchEntity(fileName: "ziraat.pdf",
                                                             addedCount: 2))
        try await store.parserProfiles.save(ParserProfileEntity(bankName: "Ziraat",
                                                                formatIdentifier: "ziraat.v1"))
        try await store.categoryRules.save(CategoryRuleEntity(keyword: "MIGROS",
                                                              categoryID: category.id))
        try await store.transactions.saveAll([
            TransactionEntity(date: Self.date(12), amount: Money(minorUnits: 84_260),
                              direction: .expense, detail: "Migros Ataşehir",
                              categoryID: category.id, accountID: account.id),
            TransactionEntity(date: Self.date(5), amount: Money(minorUnits: 5_240_000),
                              direction: .income, detail: "Maaş", accountID: account.id)
        ])
        return (account.id, category.id)
    }

    @Test("Arşiv defterin tamamını taşır")
    func arsivIcerigi() async throws {
        let store = try makeStore()
        _ = try await seed(store)
        let archive = try await BackupService(store: store).makeArchive()

        #expect(archive.version == BackupArchive.currentVersion)
        #expect(archive.accounts.count == 1)
        #expect(archive.categories.count == 1)
        #expect(archive.transactions.count == 2)
        #expect(archive.budgets.count == 1)
        #expect(archive.importBatches.count == 1)
        #expect(archive.parserProfiles.count == 1)
        #expect(archive.categoryRules.count == 1)
        #expect(archive.summary == "2 işlem · 1 hesap · 1 bütçe")
    }

    @Test("JSON kodlama gidiş dönüşü alan kaybetmez")
    func jsonGidisDonus() async throws {
        let store = try makeStore()
        _ = try await seed(store)
        let archive = try await BackupService(store: store).makeArchive()

        let data = try BackupArchive.encode(archive)
        let decoded = try BackupArchive.decode(data)
        #expect(decoded == archive)
    }

    @Test("Şifreli dosyadan geri yükleme defteri birebir kurar")
    func sifreliGidisDonus() async throws {
        let source = try makeStore()
        _ = try await seed(source)
        let archive = try await BackupService(store: source).makeArchive()
        let sealed = try PasswordCrypto.encrypt(try BackupArchive.encode(archive),
                                                password: "yedek-parolasi",
                                                iterations: 1_000)

        let target = try makeStore()
        let opened = try BackupArchive.decode(
            try PasswordCrypto.decrypt(sealed, password: "yedek-parolasi"))
        try await BackupService(store: target).restore(opened)

        #expect(try await target.transactions.count(matching: .all) == 2)
        #expect(try await target.accounts.all(includeArchived: true).count == 1)
        #expect(try await target.categoryRules.all().count == 1)
        let restored = try await BackupService(store: target).makeArchive()
        #expect(Set(restored.transactions.map(\.id)) == Set(archive.transactions.map(\.id)))
    }

    @Test("Geri yükleme mevcut defteri değiştirir, birleştirmez")
    func geriYuklemeYikici() async throws {
        let source = try makeStore()
        _ = try await seed(source)
        let archive = try await BackupService(store: source).makeArchive()

        let target = try makeStore()
        let strayAccount = AccountEntity(name: "Eski hesap", kind: .cash)
        try await target.accounts.save(strayAccount)
        try await target.transactions.save(TransactionEntity(
            date: Self.date(1), amount: Money(minorUnits: 999), direction: .expense,
            detail: "Silinecek", accountID: strayAccount.id))

        try await BackupService(store: target).restore(archive)

        #expect(try await target.transactions.count(matching: .all) == 2)
        let accounts = try await target.accounts.all(includeArchived: true)
        #expect(accounts.count == 1)
        #expect(accounts.first?.name == "Ziraat")
    }

    @Test("Boş arşiv ve gelecek sürüm reddedilir")
    func gecersizArsiv() async throws {
        let store = try makeStore()
        let service = BackupService(store: store)

        await #expect(throws: BackupError.emptyArchive) {
            try await service.restore(BackupArchive())
        }
        var future = BackupArchive(accounts: [AccountEntity(name: "X", kind: .cash)])
        future.version = BackupArchive.currentVersion + 1
        await #expect(throws: BackupError.unsupportedVersion(future.version)) {
            try await service.restore(future)
        }
    }

    @Test("Dosya adı tarihten türer")
    func dosyaAdi() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        #expect(BackupFile.suggestedName(for: Self.date(14), calendar: calendar)
                == "SessizDefter-2026-08-14.sdb")
    }
}
