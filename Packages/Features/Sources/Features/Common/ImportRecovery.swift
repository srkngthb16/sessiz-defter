import Domain
import Foundation

/// Yarım kalan içe aktarmayı açılışta onarır.
///
/// İçe aktarma parti kaydını "tamamlanmadı" işaretiyle açıyor, işlemleri yazıyor,
/// sonra partiyi tamamlıyor. Uygulama arada ölürse geriye tamamlanmamış bir parti
/// kalıyor. İki durum var, ikisi de veri kaybetmeden kapanıyor:
///
/// - Parti açıldı ama işlem yazılmadı: parti kaydı silinir, defterde iz kalmaz.
/// - İşlemler yazıldı ama parti tamamlanmadı: parti gerçekte yazılan satır
///   sayısıyla tamamlanır. İşlemler silinmiyor — kullanıcının verisi duruyor,
///   silmek geri alınamaz bir karar olurdu.
public enum ImportRecovery {
    public struct Outcome: Equatable, Sendable {
        /// Kaydı silinen (hiç satır yazmamış) parti sayısı.
        public var discardedBatches = 0
        /// Tamamlanmış olarak işaretlenen parti sayısı.
        public var completedBatches = 0
        /// Tamamlanan partilerdeki toplam işlem sayısı.
        public var recoveredTransactions = 0

        public var didRepairAnything: Bool {
            discardedBatches > 0 || completedBatches > 0
        }
    }

    @discardableResult
    public static func repair(in environment: AppEnvironment) async throws -> Outcome {
        var outcome = Outcome()
        // Parti tablosu küçük, taraması bedava. Kaçınılan şey işlemlerin taranması.
        for batch in try await environment.importBatches.all() where !batch.isComplete {
            let written = try await environment.transactions.count(inBatch: batch.id)
            if written == 0 {
                try await environment.importBatches.delete(id: batch.id)
                outcome.discardedBatches += 1
            } else {
                var repaired = batch
                repaired.isComplete = true
                // Bildirilen sayı değil gerçekte yazılan sayı: yarım kalan partide
                // ikisi tutmuyor ve geçmiş yanlış rakam gösteriyordu.
                repaired.addedCount = written
                try await environment.importBatches.save(repaired)
                outcome.completedBatches += 1
                outcome.recoveredTransactions += written
            }
        }
        return outcome
    }
}
