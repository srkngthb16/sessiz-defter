import Domain
import Foundation

/// Örnek defteri yazan ve geri alan tek yol. Yükleme ile temizleme aynı dosyada
/// duruyor: ikisi aynı kimlik kümesine bakmazsa temizleme eksik kalır ve kullanıcı
/// silemediği sahte kayıtlarla kalır.
public enum SampleData {
    public static func isLoaded(in environment: AppEnvironment) async -> Bool {
        let batches = (try? await environment.importBatches.all()) ?? []
        return batches.contains { $0.id == SampleLedger.batchID }
    }

    /// Zaten yüklüyse hiçbir şey yapmaz — iki kez basıldığında 40 işlem oluşmasın.
    public static func load(into environment: AppEnvironment) async throws {
        guard await isLoaded(in: environment) == false else { return }

        // Varsayılan kategoriler Dashboard açılışında tohumlanıyor; örnek veri
        // onboarding'de yazıldığı için o an defter kategorisiz oluyordu ve 20
        // işlemin tamamı "Kategorisiz" görünüyordu (simülatörde yakalandı).
        _ = try await environment.service.seedDefaultCategoriesIfNeeded()
        let categories = try await environment.categories.all(includeArchived: false)
        let ledger = SampleLedger.make(now: environment.now(),
                                       calendar: environment.calendar,
                                       categories: categories)

        try await environment.accounts.save(ledger.account)
        try await environment.transactions.saveAll(ledger.transactions)
        for budget in ledger.budgets {
            try await environment.budgets.save(budget)
        }
        // Batch en son yazılıyor: "yüklü mü" sorusunun yanıtı bu kayıt. Yazma
        // ortada kesilirse örnek veri "yüklenmemiş" sayılır ve tekrar denenebilir.
        try await environment.importBatches.save(ledger.batch)
    }

    /// Yalnızca örnek batch'e bağlı kayıtları siler. Kullanıcı örnek hesaba kendi
    /// işlemini eklediyse o işlem de hesap da yerinde kalır.
    public static func clear(from environment: AppEnvironment) async throws {
        let all = try await environment.transactions.transactions(matching: .all)
        for transaction in all where transaction.importBatchID == SampleLedger.batchID {
            try await environment.transactions.delete(id: transaction.id)
        }
        for id in [SampleLedger.warningBudgetID, SampleLedger.exceededBudgetID] {
            try await environment.budgets.delete(id: id)
        }
        try await environment.importBatches.delete(id: SampleLedger.batchID)

        let remaining = try await environment.transactions.transactions(matching: .all)
        let accountInUse = remaining.contains {
            $0.accountID == SampleLedger.accountID
                || $0.counterpartAccountID == SampleLedger.accountID
        }
        if !accountInUse {
            try await environment.accounts.delete(id: SampleLedger.accountID)
        }

        // Örnek hesap yazıldığı için ilk açılışta "Nakit" hiç tohumlanmamış olabilir;
        // temizlemeden sonra defter hesapsız kalıyor ve manuel giriş yapılamıyordu
        // (simülatörde yakalandı).
        _ = try await environment.service.seedDefaultAccountIfNeeded()
    }
}
