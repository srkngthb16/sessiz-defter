import Core
import Domain
import DomainTestSupport
import Foundation
import Testing

@Suite("Bellek içi repository davranışı")
struct InMemoryRepositoryTests {
    static func date(_ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar.date(from: DateComponents(year: 2026, month: 8, day: day))!
    }

    struct Fixture {
        let store = InMemoryStore()
        let account = AccountEntity(name: "Ziraat", kind: .checking, maskedNumber: "••3412")
        let otherAccount = AccountEntity(name: "Garanti", kind: .creditCard, maskedNumber: "••8871")
        let market = CategoryEntity(name: "Market", colorIndex: 0, symbolName: "cart")
        let transport = CategoryEntity(name: "Ulaşım", colorIndex: 1, symbolName: "car")

        func seeded() async -> Self {
            let rows = [
                TransactionEntity(date: date(12), amount: Money(minorUnits: 84260),
                                  direction: .expense, detail: "Migros Ataşehir",
                                  categoryID: market.id, accountID: account.id),
                TransactionEntity(date: date(11), amount: Money(minorUnits: 118000),
                                  direction: .expense, detail: "Shell Otoyol",
                                  categoryID: transport.id, accountID: otherAccount.id),
                TransactionEntity(date: date(10), amount: Money(minorUnits: 850000),
                                  direction: .income, detail: "Serbest çalışma ödemesi",
                                  accountID: account.id, needsReview: true)
            ]
            await store.seed(accounts: [account, otherAccount],
                             categories: [market, transport],
                             transactions: rows)
            return self
        }

        static func date(_ day: Int) -> Date { InMemoryRepositoryTests.date(day) }
        func date(_ day: Int) -> Date { InMemoryRepositoryTests.date(day) }
    }

    @Test("İşlemler tarihe göre azalan döner")
    func siralama() async throws {
        let fixture = await Fixture().seeded()
        let repository = InMemoryTransactionRepository(store: fixture.store)
        let rows = try await repository.transactions(matching: .all)
        #expect(rows.map(\.detail) == ["Migros Ataşehir", "Shell Otoyol", "Serbest çalışma ödemesi"])
    }

    @Test("Hesap ve kategori filtresi kesişim uygular")
    func filtreler() async throws {
        let fixture = await Fixture().seeded()
        let repository = InMemoryTransactionRepository(store: fixture.store)

        let byAccount = try await repository.transactions(
            matching: TransactionQuery(accountIDs: [fixture.otherAccount.id]))
        #expect(byAccount.count == 1)
        #expect(byAccount.first?.detail == "Shell Otoyol")

        let byCategory = try await repository.transactions(
            matching: TransactionQuery(categoryIDs: [fixture.market.id]))
        #expect(byCategory.count == 1)

        let both = try await repository.transactions(
            matching: TransactionQuery(categoryIDs: [fixture.market.id],
                                       accountIDs: [fixture.otherAccount.id]))
        #expect(both.isEmpty)
    }

    @Test("Arama açıklamada ve tutarda çalışır, Türkçe harfe duyarsız")
    func arama() async throws {
        let fixture = await Fixture().seeded()
        let repository = InMemoryTransactionRepository(store: fixture.store)

        #expect(try await repository.transactions(
            matching: TransactionQuery(searchText: "migros")).count == 1)
        #expect(try await repository.transactions(
            matching: TransactionQuery(searchText: "ataşehir")).count == 1)
        #expect(try await repository.transactions(
            matching: TransactionQuery(searchText: "842,60")).count == 1)
    }

    @Test("Tutar aralığı ve kontrol filtresi")
    func tutarVeInceleme() async throws {
        let fixture = await Fixture().seeded()
        let repository = InMemoryTransactionRepository(store: fixture.store)

        let range = try await repository.transactions(matching: TransactionQuery(
            minimumAmount: Money(minorUnits: 100000),
            maximumAmount: Money(minorUnits: 500000)))
        #expect(range.map(\.detail) == ["Shell Otoyol"])

        let review = try await repository.transactions(
            matching: TransactionQuery(onlyNeedsReview: true))
        #expect(review.count == 1)
    }

    @Test("Tarih aralığı sınırları dahil")
    func tarihAraligi() async throws {
        let fixture = await Fixture().seeded()
        let repository = InMemoryTransactionRepository(store: fixture.store)
        let rows = try await repository.transactions(
            matching: TransactionQuery(dateRange: Self.date(11)...Self.date(12)))
        #expect(rows.count == 2)
    }

    @Test("Mükerrer hash sorgusu yalnızca kayıtlı olanları döner")
    func mukerrer() async throws {
        let fixture = await Fixture().seeded()
        let repository = InMemoryTransactionRepository(store: fixture.store)
        let kayitli = DuplicateHash.make(date: Self.date(12),
                                         amount: Money(minorUnits: 84260),
                                         detail: "Migros Ataşehir")
        let yeni = DuplicateHash.make(date: Self.date(1),
                                      amount: Money(minorUnits: 100),
                                      detail: "Yok")
        let found = try await repository.existingDuplicateHashes(among: [kayitli, yeni])
        #expect(found == [kayitli])
    }

    @Test("Arşivli hesap varsayılan listede gelmez")
    func arsivliHesap() async throws {
        let fixture = await Fixture().seeded()
        let repository = InMemoryAccountRepository(store: fixture.store)
        var archived = fixture.otherAccount
        archived.isArchived = true
        try await repository.save(archived)

        #expect(try await repository.all(includeArchived: false).count == 1)
        #expect(try await repository.all(includeArchived: true).count == 2)
    }

    @Test("Tüm veriyi silme her koleksiyonu boşaltır")
    func hepsiniSil() async throws {
        let fixture = await Fixture().seeded()
        try await InMemoryDataResetter(store: fixture.store).deleteEverything()
        #expect(try await InMemoryTransactionRepository(store: fixture.store)
            .transactions(matching: .all).isEmpty)
        #expect(try await InMemoryAccountRepository(store: fixture.store)
            .all(includeArchived: true).isEmpty)
    }
}
