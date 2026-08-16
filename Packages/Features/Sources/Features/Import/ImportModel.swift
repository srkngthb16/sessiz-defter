import Core
import Domain
import Foundation
import ImportPipeline

@Observable
@MainActor
public final class ImportModel {
    public enum Step: Sendable {
        case picking                                   // C1
        case processing(stage: ImportPipeline.Stage)   // C2
        case review                                    // C3
        case summary(ImportSummary)                    // C5
        case passwordRequired(attemptsLeft: Int)       // C6
        case unknownFormat(preview: [String])          // C7
        case scannedDocument                           // C8
        case failed(String)
    }

    public struct ImportSummary: Sendable {
        public var addedCount: Int
        public var skippedDuplicateCount: Int
        public var recategorizedCount: Int
        public var netEffect: Money
        public var fileName: String
        public var dateRange: ClosedRange<Date>?
    }

    public private(set) var step: Step = .picking
    public private(set) var draft: ImportDraft?
    public private(set) var categories = CategoryLookup()
    public private(set) var accounts: [AccountEntity] = []
    /// İçe aktarılan ekstrenin hangi hesaba yazılacağı. Birden fazla hesap varsa
    /// kullanıcı seçmeden başlanamaz: Garanti ekstresi Ziraat'e yazılmamalı.
    public var selectedAccountID: UUID?
    public var password = ""
    /// C5 — kullanıcı isterse kasadaki kopya silinir. Varsayılan: silinir.
    public var deletesSourceFile = true

    private let environment: AppEnvironment
    private let pipeline: ImportPipeline
    private var pendingURL: URL?
    private var passwordAttempts = 0

    public init(environment: AppEnvironment, pipeline: ImportPipeline = ImportPipeline()) {
        self.environment = environment
        self.pipeline = pipeline
    }

    /// Dosya seçiciden önce çağrılır: hesap listesi yüklenir, tek hesap varsa
    /// seçim kullanıcıya sorulmadan yapılır.
    public func loadAccounts() async {
        accounts = ((try? await environment.accounts.all(includeArchived: false)) ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
        if selectedAccountID == nil || !accounts.contains(where: { $0.id == selectedAccountID }) {
            selectedAccountID = accounts.count == 1 ? accounts.first?.id : nil
        }
    }

    /// Hesap seçilmeden dosya seçtirilmez.
    public var canPickFile: Bool {
        accounts.isEmpty || selectedAccountID != nil
    }

    public func start(url: URL, allowOCR: Bool = false,
                      fallback: GenericColumnParser? = nil) async {
        pendingURL = url
        step = .processing(stage: .extractingText)
        do {
            categories = CategoryLookup(
                try await environment.categories.all(includeArchived: false))
            let rules = try await environment.categoryRules.all()
            let accountID: UUID
            if let selectedAccountID {
                accountID = selectedAccountID
            } else {
                accountID = try await defaultAccountID()
            }

            step = .processing(stage: .detectingFormat)
            let hashes = Set<String>()
            step = .processing(stage: .parsingRows)
            var result = try await pipeline.run(ImportPipeline.Input(
                url: url, password: password.isEmpty ? nil : password,
                allowOCR: allowOCR, fallbackParser: fallback,
                accountID: accountID, rules: rules, existingHashes: hashes))

            step = .processing(stage: .categorizing)
            // Mükerrer sorgusu ayrıştırma bittikten sonra: hash'ler ancak burada belli.
            let existing = try await environment.transactions.existingDuplicateHashes(
                among: Set(result.rows.map(\.duplicateHash).filter { !$0.isEmpty }))
            for index in result.rows.indices where existing.contains(result.rows[index].duplicateHash) {
                result.rows[index].kind = .duplicate
                result.rows[index].isSelected = false
            }
            draft = result
            step = .review
        } catch let error as ImportError {
            handle(error)
        } catch {
            step = .failed(String(describing: error))
        }
    }

    public func retryWithPassword() async {
        guard let pendingURL else { return }
        passwordAttempts += 1
        await start(url: pendingURL)
    }

    public func retryWithOCR() async {
        guard let pendingURL else { return }
        await start(url: pendingURL, allowOCR: true)
    }

    public func retryWithColumns(_ columns: [ColumnRole], separator: Character?) async {
        guard let pendingURL else { return }
        let parser = GenericColumnParser(
            formatIdentifier: "kullanici.\(UUID().uuidString.prefix(8)).v1",
            bankName: "Şablon", separator: separator, columns: columns)
        await start(url: pendingURL, fallback: parser)
    }

    public func toggle(_ rowID: UUID) {
        guard let index = draft?.rows.firstIndex(where: { $0.id == rowID }) else { return }
        draft?.rows[index].isSelected.toggle()
    }

    public func assign(categoryID: UUID, to rowIDs: Set<UUID>) {
        guard draft != nil else { return }
        for index in draft!.rows.indices where rowIDs.contains(draft!.rows[index].id) {
            draft!.rows[index].categoryID = categoryID
            draft!.rows[index].wasRecategorized = true
            if draft!.rows[index].kind == .needsReview {
                draft!.rows[index].kind = .automatic
            }
        }
    }

    /// C4 — "PAPARA içeren satırlar → Transfer" kuralı kaydedilir.
    public func saveRule(keyword: String, categoryID: UUID) async {
        let rule = CategoryRuleEntity(keyword: keyword, categoryID: categoryID)
        try? await environment.categoryRules.save(rule)
    }

    public func confirm() async {
        guard let draft else { return }
        do {
            let accountID: UUID
            if let selectedAccountID {
                accountID = selectedAccountID
            } else {
                accountID = try await defaultAccountID()
            }
            let batchID = UUID()
            let builder = DraftBuilder(categorizer: CategorizationEngine(rules: []),
                                       accountID: accountID)
            let entities = builder.transactions(from: draft, importBatchID: batchID)

            // Tek yazma işlemi: biri düşerse hiçbiri kalmaz.
            try await environment.transactions.saveAll(entities)
            try await environment.importBatches.save(ImportBatchEntity(
                id: batchID, fileName: draft.fileName,
                periodStart: draft.dateRange?.lowerBound,
                periodEnd: draft.dateRange?.upperBound,
                addedCount: entities.count,
                skippedDuplicateCount: draft.duplicateCount,
                manuallyRecategorizedCount: draft.rows.filter(\.wasRecategorized).count,
                bankFormatIdentifier: draft.formatIdentifier,
                sourceFileRetained: !deletesSourceFile,
                usedOCR: draft.usedOCR))

            if deletesSourceFile, let pendingURL {
                try? FileManager.default.removeItem(at: pendingURL)
            }

            step = .summary(ImportSummary(
                addedCount: entities.count,
                skippedDuplicateCount: draft.duplicateCount,
                recategorizedCount: draft.rows.filter(\.wasRecategorized).count,
                netEffect: draft.netEffect,
                fileName: draft.fileName,
                dateRange: draft.dateRange))
        } catch {
            step = .failed(String(describing: error))
        }
    }

    public func cancel() {
        // İptalde kasadaki kopya bırakılmaz.
        if let pendingURL { try? FileManager.default.removeItem(at: pendingURL) }
        pendingURL = nil
        draft = nil
        password = ""
        step = .picking
    }

    private func handle(_ error: ImportError) {
        switch error {
        case .passwordProtected:
            step = .passwordRequired(attemptsLeft: max(0, 2 - passwordAttempts))
        case .noTextLayer:
            step = .scannedDocument
        case .unknownFormat(let preview):
            step = .unknownFormat(preview: preview)
        case .fileUnreadable:
            step = .failed("Dosya okunamadı.")
        case .ocrFailed:
            step = .failed("Metin tanınamadı.")
        }
    }

    private func defaultAccountID() async throws -> UUID {
        let accounts = try await environment.accounts.all(includeArchived: false)
        if let first = accounts.first { return first.id }
        let fallback = AccountEntity(name: "Nakit", kind: .cash)
        try await environment.accounts.save(fallback)
        return fallback.id
    }
}
