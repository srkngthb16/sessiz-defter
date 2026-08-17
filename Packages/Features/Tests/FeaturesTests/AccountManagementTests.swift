import Core
import Domain
import DomainTestSupport
import Foundation
import ImportPipeline
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

    @Test("Tek hesap varken bile seçim boş kalır: hedef ekstreden bulunur")
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
        // Önceden tek hesap otomatik seçiliyordu; yeni kurulumda o hesap "Nakit"
        // olduğu için bütün banka ekstreleri nakde yazılıyordu.
        #expect(model.selectedAccountID == nil)
        #expect(model.canPickFile)
        #expect(account.name == "Nakit")
    }

    @Test("Hesap seçmeden dosya seçilebilir: hedef ekstreden bulunur")
    func secimZorunluDegil() async {
        let environment = await Fixtures.environment()
        let model = ImportModel(environment: environment)
        await model.loadAccounts()

        #expect(model.accounts.count == 2)
        #expect(model.selectedAccountID == nil)
        // Önceden hesap seçilmeden dosya seçilemiyordu; artık banka ekstreden
        // çıkarıldığı için seçim yalnız elle geçersiz kılma.
        #expect(model.canPickFile)
    }

    @Test("Ekstre son dört haneyle var olan hesaba eşleşir")
    func maskeyleEslesme() async throws {
        let environment = await Fixtures.environment()
        let model = ImportModel(environment: environment)
        await model.loadAccounts()

        // Fixture'daki Ziraat hesabının maskesi "••3412".
        let draft = ImportDraft(fileName: "ekstre.pdf", formatIdentifier: "ziraat.vadesiz.v1",
                                bankName: "Ziraat Bankası", maskedNumber: "••3412",
                                accountKind: .checking, rows: [])
        let resolved = try await model.resolveAccountID(for: draft)
        #expect(resolved == Fixtures.ziraat.id)

        let sonra = try await environment.accounts.all(includeArchived: true)
        #expect(sonra.count == 2, "eşleşen hesap varken yenisi açılmamalı")
    }

    @Test("Eşleşme yoksa ekstredeki bankadan yeni hesap açılır")
    func eslesmeYoksaHesapAcilir() async throws {
        let environment = await Fixtures.environment()
        let model = ImportModel(environment: environment)
        await model.loadAccounts()

        let draft = ImportDraft(fileName: "kart.pdf", formatIdentifier: "halkbank.paraf.v1",
                                bankName: "Halkbank", maskedNumber: "••3682",
                                accountKind: .creditCard, rows: [])
        let resolved = try await model.resolveAccountID(for: draft)

        let hesaplar = try await environment.accounts.all(includeArchived: true)
        let yeni = try #require(hesaplar.first { $0.id == resolved })
        #expect(yeni.name == "Halkbank")
        #expect(yeni.kind == .creditCard)
        #expect(yeni.maskedNumber == "••3682")
        #expect(hesaplar.count == 3)
    }

    @Test("Elle seçim otomatik eşleşmeyi geçersiz kılar")
    func elleSecimKazanir() async throws {
        let environment = await Fixtures.environment()
        let model = ImportModel(environment: environment)
        await model.loadAccounts()
        model.selectedAccountID = Fixtures.garanti.id

        let draft = ImportDraft(fileName: "ekstre.pdf", formatIdentifier: "ziraat.vadesiz.v1",
                                bankName: "Ziraat Bankası", maskedNumber: "••3412",
                                accountKind: .checking, rows: [])
        #expect(try await model.resolveAccountID(for: draft) == Fixtures.garanti.id)
    }

    @Test("Hesap adı maskeyle birleşir, maske dört haneden kısa olamaz")
    func maskeBicimi() {
        let withMask = AccountEntity(name: "Ziraat", kind: .checking, maskedNumber: "••3412")
        #expect(withMask.displayName == "Ziraat ••3412")
        #expect(AccountEntity(name: "Nakit", kind: .cash).displayName == "Nakit")
    }
}
