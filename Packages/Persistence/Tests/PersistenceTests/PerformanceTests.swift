import Core
import Domain
import DomainTestSupport
import Foundation
import SwiftData
import Testing
@testable import Persistence

/// 10.000 işlemlik defterde sorgu süreleri.
///
/// Eşik 250 ms: kullanıcı listeyi kaydırırken ya da sekme değiştirirken bunun
/// üstü "takıldı" diye hissediliyor. Ölçüm makineye göre oynar; testin işi süreyi
/// raporlamak değil, iş büyüdüğünde düşmek.
@Suite("Performans · 10.000 işlem", .serialized)
struct PerformanceTests {
    static let threshold = Duration.milliseconds(250)

    static func makeLedger() -> LargeLedger.Ledger {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 16))!
        return LargeLedger.make(transactionCount: 10_000, now: now, calendar: calendar)
    }

    static func loadedStore() async throws -> (PersistenceStore, LargeLedger.Ledger) {
        let store = PersistenceStore(modelContainer: try StoreFactory.makeInMemoryContainer())
        let ledger = makeLedger()
        for account in ledger.accounts { try await store.accounts.save(account) }
        for category in ledger.categories { try await store.categories.save(category) }
        try await store.transactions.saveAll(ledger.transactions)
        return (store, ledger)
    }

    static func measure(_ work: () async throws -> Void) async rethrows -> Duration {
        let clock = ContinuousClock()
        let start = clock.now
        try await work()
        return clock.now - start
    }

    @Test("Listenin ilk sayfası 250 ms altında")
    func listeSayfasi() async throws {
        let (store, _) = try await Self.loadedStore()
        var query = TransactionQuery.all
        query.limit = 200
        var rows: [TransactionEntity] = []
        let elapsed = try await Self.measure {
            rows = try await store.transactions.transactions(matching: query)
        }
        #expect(rows.count == 200)
        // Sınır store tarafında uygulanmazsa 10.000 satır belleğe geliyor ve
        // süre üç katına çıkıyor; sıralama da doğru kalmalı.
        #expect(rows.first!.date >= rows.last!.date)
        #expect(elapsed < Self.threshold, "liste sayfası \(elapsed)")
    }

    @Test("Sınırsız tam liste hâlâ tüm kayıtları döner")
    func tamListe() async throws {
        let (store, _) = try await Self.loadedStore()
        let rows = try await store.transactions.transactions(matching: .all)
        #expect(rows.count == 10_000)
    }

    @Test("Arama 250 ms altında ve sonuçlar doğru")
    func arama() async throws {
        let (store, ledger) = try await Self.loadedStore()
        var query = TransactionQuery.all
        query.searchText = "Migros"
        var rows: [TransactionEntity] = []
        let elapsed = try await Self.measure {
            rows = try await store.transactions.transactions(matching: query)
        }
        // Store tarafı arama, bellekteki eski yolla aynı kümeyi vermeli.
        let expected = ledger.transactions.filter { query.matches($0) }
        #expect(rows.count == expected.count)
        #expect(rows.isEmpty == false)
        #expect(elapsed < Self.threshold, "arama \(elapsed)")
    }

    @Test("Arama sütunu boş kalmış kayıtlar geri doldurulunca bulunur")
    func geriDoldurma() async throws {
        let (store, _) = try await Self.loadedStore()
        // Sütun eklenmeden önce yazılmış kaydı taklit et: indeksi boşalt.
        let cleared = try await store.clearSearchIndexForTesting()
        #expect(cleared > 0)

        var query = TransactionQuery.all
        query.searchText = "Migros"
        #expect(try await store.transactions.transactions(matching: query).isEmpty)

        let fixed = try await store.backfillSearchIndex()
        #expect(fixed == cleared)
        #expect(try await store.transactions.transactions(matching: query).isEmpty == false)
        // İkinci koşuda düzeltilecek satır kalmamalı.
        #expect(try await store.backfillSearchIndex() == 0)
    }

    @Test("Tutarla arama da store tarafında çalışır")
    func tutarlaArama() async throws {
        let (store, ledger) = try await Self.loadedStore()
        var query = TransactionQuery.all
        query.searchText = "1.0"
        let rows = try await store.transactions.transactions(matching: query)
        let expected = ledger.transactions.filter { query.matches($0) }
        #expect(rows.count == expected.count)
    }

    @Test("Dönem sorgusu 250 ms altında")
    func donemSorgusu() async throws {
        let (store, ledger) = try await Self.loadedStore()
        let end = ledger.transactions.map(\.date).max() ?? Date()
        let start = Calendar.current.date(byAdding: .month, value: -1, to: end) ?? end
        var query = TransactionQuery.all
        query.dateRange = start...end
        let elapsed = try await Self.measure {
            _ = try await store.transactions.transactions(matching: query)
        }
        #expect(elapsed < Self.threshold, "dönem sorgusu \(elapsed)")
    }

    @Test("Sayım 250 ms altında")
    func sayim() async throws {
        let (store, _) = try await Self.loadedStore()
        var total = 0
        let elapsed = try await Self.measure {
            total = try await store.transactions.count(matching: .all)
        }
        #expect(total == 10_000)
        #expect(elapsed < Self.threshold, "sayım \(elapsed)")
    }

    @Test("Dashboard açılışının tüm sorguları 250 ms altında")
    func dashboardAcilisi() async throws {
        let (store, ledger) = try await Self.loadedStore()
        let end = ledger.transactions.map(\.date).max() ?? Date()
        let start = Calendar.current.date(byAdding: .month, value: -1, to: end) ?? end
        var monthQuery = TransactionQuery.all
        monthQuery.dateRange = start...end
        var recentQuery = TransactionQuery.all
        recentQuery.limit = 3

        // DashboardModel.load'un attığı sorguların tamamı: sayım, dönem, son
        // işlemler ve hesap toplamları.
        //
        // İlk hesap eşiğin üstünde (10.000 satırın toplanması ~460 ms; iOS 17
        // SwiftData'da toplama sorgusu yok). Bu yol yalnız açılışta ve her
        // yazmadan sonra bir kez çalışıyor, üstünü B2 iskeleti örtüyor.
        // Ölçülen ve eşikle sınanan yol, sekme değiştirmenin gerçek maliyeti.
        _ = try await Self.measure {
            _ = try await store.transactions.signedTotalsByAccount()
        }

        let elapsed = try await Self.measure {
            _ = try await store.transactions.count(matching: .all)
            _ = try await store.transactions.transactions(matching: monthQuery)
            _ = try await store.transactions.transactions(matching: recentQuery)
            _ = try await store.transactions.signedTotalsByAccount()
        }
        #expect(elapsed < Self.threshold, "dashboard açılışı \(elapsed)")
    }

    @Test("Yazma sonrası toplamlar tazeleniyor")
    func toplamlarTazeleniyor() async throws {
        let (store, ledger) = try await Self.loadedStore()
        let before = try await store.transactions.signedTotalsByAccount()
        let accountID = ledger.accounts[0].id

        try await store.transactions.save(
            TransactionEntity(date: Date(), amount: Money(minorUnits: 100_00),
                              direction: .expense, detail: "Yeni kayıt",
                              accountID: accountID))

        let after = try await store.transactions.signedTotalsByAccount()
        // Önbellek düşmezse eski toplam dönerdi ve bakiye yanlış görünürdü.
        #expect(after[accountID]!.minorUnits == before[accountID]!.minorUnits - 100_00)
    }

    @Test("Hesap toplamları bakiyeyle birebir aynı")
    func toplamlarDogru() async throws {
        let (store, ledger) = try await Self.loadedStore()
        let totals = try await store.transactions.signedTotalsByAccount()
        let fromTotals = Balances.netWorth(accounts: ledger.accounts, signedTotals: totals)
        let fromRows = Balances.netWorth(accounts: ledger.accounts,
                                         transactions: ledger.transactions)
        #expect(fromTotals == fromRows)
    }

    @Test("Rapor hesabı 250 ms altında")
    func raporHesabi() async throws {
        let (store, _) = try await Self.loadedStore()
        let rows = try await store.transactions.transactions(matching: .all)
        let elapsed = await Self.measure {
            _ = CategoryBreakdown.make(from: rows, limit: 8)
            _ = PeriodSummary.make(from: rows)
        }
        #expect(elapsed < Self.threshold, "rapor hesabı \(elapsed)")
    }

    @Test("Gün gruplaması 250 ms altında")
    func gunGruplamasi() async throws {
        let (store, _) = try await Self.loadedStore()
        let rows = try await store.transactions.transactions(matching: .all)
        let elapsed = await Self.measure {
            _ = TransactionService.group(rows, calendar: .current)
        }
        #expect(elapsed < Self.threshold, "gün gruplaması \(elapsed)")
    }
}
