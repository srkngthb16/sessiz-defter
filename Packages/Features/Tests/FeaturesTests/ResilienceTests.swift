import Core
import Domain
import Foundation
import Testing
@testable import Features

@Suite("Dayanıklılık")
@MainActor
struct ResilienceTests {
    /// İçe aktarma sırasında ölmüş uygulamayı taklit eder: parti "tamamlanmadı"
    /// işaretiyle duruyor, işlemler kısmen yazılmış olabiliyor.
    private func interruptedImport(
        writtenRows: Int,
        reportedCount: Int
    ) async throws -> (AppEnvironment, UUID) {
        let environment = await Fixtures.environment()
        let batchID = UUID()
        var batch = ImportBatchEntity(id: batchID, fileName: "ekstre.pdf",
                                      addedCount: reportedCount)
        batch.isComplete = false
        try await environment.importBatches.save(batch)

        let rows = (0..<writtenRows).map { index in
            TransactionEntity(date: Fixtures.today,
                              amount: Money(minorUnits: 10_00 + index),
                              direction: .expense, detail: "Satır \(index)",
                              accountID: Fixtures.ziraat.id,
                              source: .statement, importBatchID: batchID)
        }
        if !rows.isEmpty { try await environment.transactions.saveAll(rows) }
        return (environment, batchID)
    }

    @Test("Hiç satır yazmamış yarım parti silinir")
    func bosParti() async throws {
        let (environment, batchID) = try await interruptedImport(writtenRows: 0,
                                                                 reportedCount: 42)
        let outcome = try await ImportRecovery.repair(in: environment)

        #expect(outcome.discardedBatches == 1)
        #expect(outcome.completedBatches == 0)
        #expect(try await environment.importBatches.batch(id: batchID) == nil)
    }

    @Test("Satır yazmış yarım parti gerçek sayısıyla tamamlanır, işlemler durur")
    func yarimParti() async throws {
        let (environment, batchID) = try await interruptedImport(writtenRows: 7,
                                                                 reportedCount: 42)
        let before = try await environment.transactions.count(matching: .all)

        let outcome = try await ImportRecovery.repair(in: environment)

        #expect(outcome.completedBatches == 1)
        #expect(outcome.recoveredTransactions == 7)
        let batch = try #require(await environment.importBatches.batch(id: batchID))
        #expect(batch.isComplete)
        // Bildirilen 42 değil gerçekte yazılan 7 kalmalı.
        #expect(batch.addedCount == 7)
        // Kullanıcının verisi silinmiyor.
        #expect(try await environment.transactions.count(matching: .all) == before)
    }

    @Test("Tamamlanmış partilere dokunulmaz, ikinci onarım boş geçer")
    func tamamlanmisParti() async throws {
        let (environment, _) = try await interruptedImport(writtenRows: 3,
                                                           reportedCount: 3)
        _ = try await ImportRecovery.repair(in: environment)

        let ikinci = try await ImportRecovery.repair(in: environment)
        #expect(ikinci.didRepairAnything == false)
    }

    @Test("Yedek arşivi yarım kalan parti işaretini taşır")
    func arsivIsaretiTasir() throws {
        var batch = ImportBatchEntity(fileName: "ekstre.pdf", addedCount: 5)
        batch.isComplete = false
        let archive = BackupArchive(importBatches: [batch])
        let restored = try BackupArchive.decode(try BackupArchive.encode(archive))
        #expect(restored.importBatches.first?.isComplete == false)
    }

    @Test("Alanı olmayan eski yedek tamamlanmış sayılır")
    func eskiArsiv() throws {
        // 10.3 öncesi yedeklerde isComplete alanı yok; okurken tamamlanmış kabul
        // edilmezse geçmiş içe aktarmalar yarım görünürdü.
        let json = """
        {"id":"\(UUID().uuidString)","fileName":"eski.pdf","importedAt":776000000,\
        "addedCount":12,"skippedDuplicateCount":0,"manuallyRecategorizedCount":0,\
        "sourceFileRetained":false,"usedOCR":false}
        """
        let batch = try JSONDecoder().decode(ImportBatchEntity.self,
                                             from: Data(json.utf8))
        #expect(batch.isComplete)
        #expect(batch.addedCount == 12)
    }
}
