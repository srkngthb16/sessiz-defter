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
    /// C7 sonrası rapor: kaç satır tarandı, kaç okundu, kaç atlandı.
    public private(set) var report: ParseReport?
    /// Ayrıştırılamayan ekstrenin ham metni. Yalnızca bellekte durur; kullanıcı
    /// isterse anonimleştirilmiş hâli paylaşılır.
    public private(set) var extractedText: String?
    /// Kullanıcı eşlemesi kaydedilsin mi (C7).
    public var savesMapping = true
    public var mappedBankName = ""
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

    /// Dosya seçiciden önce çağrılır: hesap listesi yüklenir.
    ///
    /// Hiçbir hesap önceden seçilmiyor. Önceden tek hesap varsa o seçiliyordu;
    /// yeni kurulumda tek hesap "Nakit" olduğu için bütün banka ekstreleri nakde
    /// yazıldı ve ekstreden banka tanıma hiç devreye girmedi.
    public func loadAccounts() async {
        accounts = ((try? await environment.accounts.all(includeArchived: false)) ?? [])
            .sorted { $0.sortIndex < $1.sortIndex }
        if let current = selectedAccountID, !accounts.contains(where: { $0.id == current }) {
            selectedAccountID = nil
        }
    }

    /// Hesap seçilmeden dosya seçtirilmez.
    /// Artık her zaman açık: hedef hesap ekstreden çıkarılıyor, seçim yalnız
    /// elle geçersiz kılma. Önceden hesap seçilmeden dosya seçilemiyordu.
    public var canPickFile: Bool { true }

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
            // Kullanıcının kaydettiği eşlemeler yerleşik parser'lardan önce denenir.
            let savedProfiles = ((try? await environment.parserProfiles?.all()) ?? []) ?? []
            let scopedPipeline = ImportPipeline(
                detector: BankFormatDetector(savedProfiles: savedProfiles))
            let output = try await scopedPipeline.runDetailed(ImportPipeline.Input(
                url: url, password: password.isEmpty ? nil : password,
                allowOCR: allowOCR, fallbackParser: fallback,
                accountID: accountID, rules: rules, existingHashes: hashes))
            report = output.report
            extractedText = output.extractedText
            var result = output.draft

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
            // Sayaca yalnızca sayı gider; hata metni ekranda kalır, rapora girmez.
            environment.diagnostics.record(.statementImport)
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

    /// C7 — kullanıcı eşlemesiyle yeniden dener. Eşleme kaydedilirse aynı bankanın
    /// sonraki ekstresi otomatik tanınır; imza türetilemezse kayıt anlamsız olur.
    public func retryWithColumns(_ columns: [ColumnRole], separator: Character?) async {
        guard let pendingURL else { return }
        let bankName = mappedBankName.trimmingCharacters(in: .whitespaces)
        let identifier = "kullanici.\(UUID().uuidString.prefix(8)).v1"
        let signatures = extractedText.map { StatementSignature.derive(from: $0) } ?? []

        if savesMapping, !signatures.isEmpty, !bankName.isEmpty {
            try? await environment.parserProfiles?.save(ParserProfileEntity(
                bankName: bankName,
                formatIdentifier: identifier,
                signatures: signatures,
                columnMapping: columns,
                separator: separator.map(String.init),
                isUserDefined: true))
        }

        let parser = GenericColumnParser(
            formatIdentifier: identifier,
            bankName: bankName.isEmpty ? "Şablon" : bankName,
            separator: separator, columns: columns, signatures: signatures)
        await start(url: pendingURL, fallback: parser)
    }

    /// C7 canlı önizleme: eşleme uygulanınca ilk satırlar nasıl okunuyor.
    public func previewRows(columns: [ColumnRole], separator: Character?,
                            limit: Int = 4) -> [ParsedRow] {
        guard let extractedText else { return [] }
        let parser = GenericColumnParser(
            formatIdentifier: "onizleme", bankName: "Önizleme",
            separator: separator, columns: columns)
        return Array(parser.parse(extractedText, calendar: environment.calendar)
            .rows.prefix(limit))
    }

    /// Ayrıştırılamayan ekstrenin paylaşılabilir hâli. Uygulama hiçbir şey göndermez;
    /// metni sistem paylaşım sayfasına veren kullanıcıdır.
    public var anonymizedSample: String? {
        guard let extractedText else { return nil }
        return """
        Sessiz Defter · ayrıştırılamayan ekstre örneği
        Bu metin anonimleştirildi: harfler X, rakamlar 9 ile değiştirildi.
        Yalnızca satır düzeni ve ayraçlar korundu.

        \(StatementAnonymizer.anonymize(extractedText))
        """
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

    /// Ekstrenin yazılacağı hesap. Kullanıcı elle seçtiyse onun seçimi kazanır;
    /// seçmediyse ekstrenin kendi bilgisinden bulunur, yoksa yeni hesap açılır.
    /// Böylece "hangi bankaya" sorusu her içe aktarmada sorulmuyor, ama işlemler
    /// tek torbaya da yığılmıyor — banka bazlı takip bu eşleşmeye dayanıyor.
    func resolveAccountID(for draft: ImportDraft) async throws -> UUID {
        if let selectedAccountID { return selectedAccountID }

        let existing = try await environment.accounts.all(includeArchived: true)
        // Son dört hane en kesin ölçüt: aynı bankada iki kart olabiliyor.
        if let masked = draft.maskedNumber,
           let match = existing.first(where: { $0.maskedNumber == masked }) {
            return match.id
        }
        if let match = existing.first(where: {
            $0.name == draft.bankName && $0.kind == draft.accountKind
        }) {
            return match.id
        }
        guard !draft.bankName.isEmpty else { return try await defaultAccountID() }

        let account = AccountEntity(
            name: draft.bankName, kind: draft.accountKind,
            maskedNumber: draft.maskedNumber, sortIndex: existing.count)
        try await environment.accounts.save(account)
        return account.id
    }

    public func confirm() async {
        guard let draft else { return }
        do {
            let accountID = try await resolveAccountID(for: draft)
            let batchID = UUID()
            let builder = DraftBuilder(categorizer: CategorizationEngine(rules: []),
                                       accountID: accountID)
            let entities = builder.transactions(from: draft, importBatchID: batchID)

            // İki aşamalı yazma: parti önce "tamamlanmadı" işaretiyle kaydedilir,
            // sonra işlemler (tek yazma işlemi — biri düşerse hiçbiri kalmaz),
            // en son parti tamamlanmış olarak güncellenir. Uygulama arada ölürse
            // yarım kalan iş küçük parti tablosundan saptanıyor; işlemleri taramak
            // 10.000 kayıtta yarım saniye sürerdi.
            let batch = ImportBatchEntity(
                id: batchID, fileName: draft.fileName,
                periodStart: draft.dateRange?.lowerBound,
                periodEnd: draft.dateRange?.upperBound,
                addedCount: entities.count,
                skippedDuplicateCount: draft.duplicateCount,
                manuallyRecategorizedCount: draft.rows.filter(\.wasRecategorized).count,
                bankFormatIdentifier: draft.formatIdentifier,
                sourceFileRetained: !deletesSourceFile,
                usedOCR: draft.usedOCR)
            var pending = batch
            pending.isComplete = false
            try await environment.importBatches.save(pending)
            try await environment.transactions.saveAll(entities)
            try await environment.importBatches.save(batch)

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
