import Core
import Domain
import Foundation

/// Yedek arşivini repository'lerden üretir ve geri yükler.
public struct BackupService: BackupServing {
    let store: PersistenceStore

    public init(store: PersistenceStore) {
        self.store = store
    }

    public func makeArchive() async throws -> BackupArchive {
        BackupArchive(
            accounts: try await store.accounts.all(includeArchived: true),
            categories: try await store.categories.all(includeArchived: true),
            transactions: try await store.transactions.transactions(matching: .all),
            budgets: try await store.budgets.all(includeArchived: true),
            importBatches: try await store.importBatches.all(),
            parserProfiles: try await store.parserProfiles.all(),
            categoryRules: try await store.categoryRules.all())
    }

    /// Geri yükleme yıkıcıdır: arşiv defterin tamamının yerine geçer, birleştirme yapılmaz.
    /// Yarım kalan bir geri yükleme karışık veri bırakacağı için önce her şey silinir.
    public func restore(_ archive: BackupArchive) async throws {
        guard archive.version <= BackupArchive.currentVersion else {
            throw BackupError.unsupportedVersion(archive.version)
        }
        guard !archive.accounts.isEmpty || !archive.transactions.isEmpty else {
            throw BackupError.emptyArchive
        }

        try await store.resetter.deleteEverything()
        for item in archive.accounts { try await store.accounts.save(item) }
        for item in archive.categories { try await store.categories.save(item) }
        for item in archive.budgets { try await store.budgets.save(item) }
        for item in archive.importBatches { try await store.importBatches.save(item) }
        for item in archive.parserProfiles { try await store.parserProfiles.save(item) }
        for item in archive.categoryRules { try await store.categoryRules.save(item) }
        try await store.transactions.saveAll(archive.transactions)
    }
}
