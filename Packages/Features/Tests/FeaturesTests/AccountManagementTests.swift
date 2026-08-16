import Core
import Domain
import DomainTestSupport
import Foundation
import Testing
@testable import Features

@Suite("Hesap yönetimi")
@MainActor
struct AccountManagementTests {
    @Test("İşlemi olan hesap silinemez, arşivlenebilir")
    func silmeEngeli() async throws {
        let environment = await Fixtures.environment()
        let accounts = try await environment.accounts.all(includeArchived: true)
        let ziraat = try #require(accounts.first { $0.name == "Ziraat" })

        // Fixture'da Ziraat üzerinde iki işlem var.
        let count = try await environment.transactions.count(
            matching: TransactionQuery(accountIDs: [ziraat.id]))
        #expect(count > 0)

        var archived = ziraat
        archived.isArchived = true
        try await environment.accounts.save(archived)
        let reloaded = try await environment.accounts.account(id: ziraat.id)
        #expect(reloaded?.isArchived == true)
        // Arşivli hesap varsayılan listede görünmez ama işlemleri durur.
        #expect(try await environment.accounts.all(includeArchived: false)
            .contains { $0.id == ziraat.id } == false)
        #expect(try await environment.transactions.count(
            matching: TransactionQuery(accountIDs: [ziraat.id])) == count)
    }

    @Test("İşlemi olmayan hesap silinir")
    func bosHesapSilinir() async throws {
        let environment = await Fixtures.environment()
        let bos = AccountEntity(name: "Yeni", kind: .cash)
        try await environment.accounts.save(bos)

        #expect(try await environment.transactions.count(
            matching: TransactionQuery(accountIDs: [bos.id])) == 0)
        try await environment.accounts.delete(id: bos.id)
        #expect(try await environment.accounts.account(id: bos.id) == nil)
    }

    @Test("Tek hesap varsa içe aktarma hedefi otomatik seçilir")
    func tekHesapOtomatik() async {
        let store = InMemoryStore()
        let account = AccountEntity(name: "Nakit", kind: .cash)
        await store.seed(accounts: [account])
        let environment = AppEnvironment(
            transactions: InMemoryTransactionRepository(store: store),
            accounts: InMemoryAccountRepository(store: store),
            categories: InMemoryCategoryRepository(store: store),
            budgets: InMemoryBudgetRepository(store: store),
            categoryRules: InMemoryCategoryRuleRepository(store: store),
            importBatches: InMemoryImportBatchRepository(store: store))

        let model = ImportModel(environment: environment)
        await model.loadAccounts()
        #expect(model.selectedAccountID == account.id)
        #expect(model.canPickFile)
    }

    @Test("Birden fazla hesap varsa seçim yapılmadan dosya seçilemez")
    func cokluHesapSecimZorunlu() async {
        let environment = await Fixtures.environment()
        let model = ImportModel(environment: environment)
        await model.loadAccounts()

        #expect(model.accounts.count == 2)
        #expect(model.selectedAccountID == nil)
        #expect(model.canPickFile == false)

        model.selectedAccountID = model.accounts.first?.id
        #expect(model.canPickFile)
    }

    @Test("Hesap adı maskeyle birleşir, maske dört haneden kısa olamaz")
    func maskeBicimi() {
        let withMask = AccountEntity(name: "Ziraat", kind: .checking, maskedNumber: "••3412")
        #expect(withMask.displayName == "Ziraat ••3412")
        #expect(AccountEntity(name: "Nakit", kind: .cash).displayName == "Nakit")
    }
}
