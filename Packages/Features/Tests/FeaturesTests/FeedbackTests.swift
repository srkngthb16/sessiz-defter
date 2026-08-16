import Core
import Domain
import DomainTestSupport
import Foundation
import Testing
@testable import Features

@Suite("Geri bildirim ve hata sayacı")
struct FeedbackTests {
    /// Her test kendi süitinde: sayaç UserDefaults'ta duruyor, testler birbirinin
    /// sayısını görmemeli.
    private func isolatedDefaults(_ name: String) -> UserDefaults {
        let suite = "feedback-tests-\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Sayaç artar, sıfırlanır")
    func sayac() {
        let diagnostics = Diagnostics(defaults: isolatedDefaults(#function))
        #expect(diagnostics.total == 0)

        diagnostics.record(.dataRead)
        diagnostics.record(.dataRead)
        diagnostics.record(.backup)
        #expect(diagnostics.count(.dataRead) == 2)
        #expect(diagnostics.count(.statementImport) == 0)
        #expect(diagnostics.total == 3)

        diagnostics.reset()
        #expect(diagnostics.total == 0)
    }

    private func report(note: String = "") -> FeedbackReport {
        FeedbackReport(appVersion: "1.0.0 (2)",
                       deviceModel: "iPhone17,3",
                       systemVersion: "26.0",
                       transactionCount: 20,
                       accountCount: 2,
                       budgetCount: 2,
                       failureCounts: [("veri okuma", 0), ("içe aktarma", 1),
                                       ("yedekleme", 0)],
                       note: note)
    }

    @Test("Metin sürüm, cihaz ve sayıları taşır")
    func metinIcerigi() {
        let text = report().text
        #expect(text.contains("1.0.0 (2)"))
        #expect(text.contains("iPhone17,3"))
        #expect(text.contains("26.0"))
        #expect(text.contains("işlem: 20"))
        #expect(text.contains("içe aktarma: 1"))
        // Sayacı sıfır olan satır da yazılır: eksik satır "gizlenmiş bilgi" izlenimi verir.
        #expect(text.contains("yedekleme: 0"))
    }

    @Test("Metinde defterden tek bir içerik parçası yok")
    func mahremiyet() {
        let text = report(note: "İçe aktarma ikinci sayfada takıldı.").text
        // Örnek defterin işyeri adları, hesap adı, maske ve para birimi işareti:
        // hiçbiri rapora girmemeli.
        let yasakli = ["Migros", "Netflix", "Kira", "Örnek Banka", "••4417", "₺", "TRY"]
        for parca in yasakli {
            #expect(text.contains(parca) == false, "\(parca) rapora sızdı")
        }
        #expect(text.contains("İçe aktarma ikinci sayfada takıldı."))
    }

    @Test("Boş not metne başlık eklemez")
    func bosNot() {
        #expect(report(note: "   \n ").text.contains("Not:") == false)
        #expect(report(note: "bir şey").text.contains("Not:"))
    }

    @Test("Simülatörde cihaz kodu ortam değişkeninden okunur")
    func cihazKodu() {
        let identifier = DeviceModel.identifier(
            environment: ["SIMULATOR_MODEL_IDENTIFIER": "iPhone17,3"])
        #expect(identifier.contains("iPhone17,3"))
        #expect(identifier.contains("simülatör"))
    }

    @Test("Okuma düşerse ekran modeli sayacı artırır")
    @MainActor
    func modelHataSayaci() async {
        let defaults = isolatedDefaults(#function)
        let store = InMemoryStore()
        let environment = AppEnvironment(
            transactions: FailingTransactionRepository(),
            accounts: InMemoryAccountRepository(store: store),
            categories: InMemoryCategoryRepository(store: store),
            budgets: InMemoryBudgetRepository(store: store),
            categoryRules: InMemoryCategoryRuleRepository(store: store),
            importBatches: InMemoryImportBatchRepository(store: store),
            calendar: Fixtures.calendar,
            now: { Fixtures.today },
            diagnostics: Diagnostics(defaults: defaults))

        let model = DashboardModel(environment: environment)
        await model.load()

        #expect(Diagnostics(defaults: defaults).count(.dataRead) == 1)
    }
}

/// Okuma hatası üreten repository: hata dalının sayaca yazdığı başka türlü
/// doğrulanamıyor.
private struct FailingTransactionRepository: TransactionRepository {
    struct Failure: Error {}

    func transactions(matching query: TransactionQuery) async throws -> [TransactionEntity] {
        throw Failure()
    }
    func transaction(id: UUID) async throws -> TransactionEntity? { throw Failure() }
    func save(_ transaction: TransactionEntity) async throws { throw Failure() }
    func saveAll(_ transactions: [TransactionEntity]) async throws { throw Failure() }
    func delete(id: UUID) async throws { throw Failure() }
    func deleteAll() async throws { throw Failure() }
    func existingDuplicateHashes(among hashes: Set<String>) async throws -> Set<String> {
        throw Failure()
    }
    func count(matching query: TransactionQuery) async throws -> Int { throw Failure() }
}
