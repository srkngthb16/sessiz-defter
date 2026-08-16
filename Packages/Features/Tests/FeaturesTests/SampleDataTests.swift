import Core
import Domain
import Foundation
import Testing
@testable import Features

@Suite("Örnek veri yükleme ve temizleme")
@MainActor
struct SampleDataTests {
    @Test("Yükleme 20 işlem ve örnek hesabı yazar")
    func yukleme() async throws {
        let environment = await Fixtures.environment(seeded: false)
        try await SampleData.load(into: environment)

        let transactions = try await environment.transactions.transactions(matching: .all)
        let accounts = try await environment.accounts.all(includeArchived: true)
        #expect(transactions.count == SampleLedger.transactionCount)
        #expect(accounts.contains { $0.id == SampleLedger.accountID })
        #expect(await SampleData.isLoaded(in: environment))
    }

    @Test("Kategori tohumlanmamış defterde de her işlem kategorili gelir")
    func kategoriler() async throws {
        // Onboarding'de örnek veri, Dashboard'ın tohumlamasından önce yazılıyor.
        let environment = await Fixtures.environment(seeded: false)
        try await SampleData.load(into: environment)

        let transactions = try await environment.transactions.transactions(matching: .all)
        #expect(transactions.allSatisfy { $0.categoryID != nil })
    }

    @Test("İkinci yükleme kayıtları çoğaltmaz")
    func tekrarYukleme() async throws {
        let environment = await Fixtures.environment(seeded: false)
        try await SampleData.load(into: environment)
        try await SampleData.load(into: environment)

        let count = try await environment.transactions.count(matching: .all)
        #expect(count == SampleLedger.transactionCount)
    }

    @Test("Temizleme örnek kayıtları siler, kullanıcının kaydına dokunmaz")
    func temizleme() async throws {
        // Dolu defterle sınanıyor: temizlemenin ayrımı boş defterde görünmez.
        let environment = await Fixtures.environment()
        let before = try await environment.transactions.transactions(matching: .all)

        try await SampleData.load(into: environment)
        try await SampleData.clear(from: environment)

        let after = try await environment.transactions.transactions(matching: .all)
        #expect(Set(after.map(\.id)) == Set(before.map(\.id)))
        #expect(await SampleData.isLoaded(in: environment) == false)

        let accounts = try await environment.accounts.all(includeArchived: true)
        #expect(accounts.contains { $0.id == SampleLedger.accountID } == false)
        #expect(accounts.count == 2)
    }

    @Test("Temizleme sonrası defter hesapsız kalmaz")
    func hesapsizKalmaz() async throws {
        // Örnek hesap yazıldığı için "Nakit" hiç tohumlanmamış olabiliyor.
        let environment = await Fixtures.environment(seeded: false)
        try await SampleData.load(into: environment)
        try await SampleData.clear(from: environment)

        let accounts = try await environment.accounts.all(includeArchived: true)
        #expect(accounts.isEmpty == false)
        #expect(accounts.contains { $0.id == SampleLedger.accountID } == false)
    }

    @Test("Örnek hesaba kullanıcı işlemi eklendiyse hesap silinmez")
    func hesapKorunur() async throws {
        let environment = await Fixtures.environment(seeded: false)
        try await SampleData.load(into: environment)
        try await environment.transactions.save(
            TransactionEntity(date: Fixtures.today, amount: Money(minorUnits: 12_500),
                              direction: .expense, detail: "Kullanıcının kendi kaydı",
                              accountID: SampleLedger.accountID))

        try await SampleData.clear(from: environment)

        let transactions = try await environment.transactions.transactions(matching: .all)
        let accounts = try await environment.accounts.all(includeArchived: true)
        #expect(transactions.count == 1)
        #expect(accounts.contains { $0.id == SampleLedger.accountID })
    }
}
