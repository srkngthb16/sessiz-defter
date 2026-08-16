import Core
import Domain
import Foundation
import Testing

@Suite("Örnek defter")
struct SampleLedgerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 16, hour: 14))!
    }

    private func ledger() -> SampleLedger.Ledger {
        SampleLedger.make(now: now, calendar: calendar, categories: DefaultCategories.seed())
    }

    @Test("20 işlem, ikisi gelir, tutarların hepsi pozitif")
    func icerik() {
        let ledger = ledger()
        #expect(ledger.transactions.count == SampleLedger.transactionCount)
        #expect(ledger.transactions.filter { $0.direction == .income }.count == 2)
        #expect(ledger.transactions.allSatisfy { $0.amount > .zero })
        #expect(ledger.transactions.contains { $0.direction == .transfer } == false)
    }

    @Test("Her işlem örnek batch'e ve örnek hesaba bağlı")
    func kimlik() {
        let ledger = ledger()
        #expect(ledger.batch.id == SampleLedger.batchID)
        #expect(ledger.account.id == SampleLedger.accountID)
        #expect(ledger.transactions.allSatisfy { $0.importBatchID == SampleLedger.batchID })
        #expect(ledger.transactions.allSatisfy { $0.accountID == SampleLedger.accountID })
    }

    @Test("Mükerrer hash'ler benzersiz — örnek veri kendi içinde çakışmaz")
    func mukerrer() {
        let hashes = Set(ledger().transactions.map(\.duplicateHash))
        #expect(hashes.count == SampleLedger.transactionCount)
    }

    @Test("Tarihler geçmişte ve son bir ay içinde")
    func tarihler() {
        let ledger = ledger()
        let sinir = calendar.date(byAdding: .day, value: -31, to: now)!
        #expect(ledger.transactions.allSatisfy { $0.date <= now })
        #expect(ledger.transactions.allSatisfy { $0.date >= sinir })
        #expect(ledger.batch.periodEnd == ledger.transactions.map(\.date).max())
    }

    @Test("Her işlemin kategorisi varsayılan listede karşılık buluyor")
    func kategoriler() {
        let seed = DefaultCategories.seed()
        let ids = Set(seed.map(\.id))
        let ledger = SampleLedger.make(now: now, calendar: calendar, categories: seed)
        #expect(ledger.transactions.allSatisfy { $0.categoryID.map(ids.contains) == true })
    }

    @Test("Kategori listesi boşsa kayıtlar kategorisiz üretilir, çökmez")
    func kategorisiz() {
        let ledger = SampleLedger.make(now: now, calendar: calendar, categories: [])
        #expect(ledger.transactions.count == SampleLedger.transactionCount)
        #expect(ledger.transactions.allSatisfy { $0.categoryID == nil })
    }

    @Test("Düşük güvenli satırlar kontrol bekliyor olarak işaretli")
    func kontrolGerekiyor() {
        let ledger = ledger()
        let review = ledger.transactions.filter(\.needsReview)
        #expect(review.isEmpty == false)
        #expect(review.allSatisfy { ($0.categoryConfidence ?? 1) < 0.6 })
        #expect(ledger.transactions.filter { ($0.categoryConfidence ?? 1) >= 0.6 }
            .allSatisfy { $0.needsReview == false })
    }
}
