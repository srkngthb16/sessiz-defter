import Core
import Domain
import Foundation
import Testing
@testable import ImportPipeline

/// Metin çıkarma sahte: PDFKit'e bağlanmadan hattın kalanını test etmek için.
struct StubExtractor: TextExtracting {
    let text: String
    var throwsNoTextLayer = false
    var ocrText: String?
    var requiresPassword: String?

    func extract(fileAt url: URL, password: String?) throws -> ExtractedText {
        if let requiresPassword, password != requiresPassword {
            throw ImportError.passwordProtected
        }
        if throwsNoTextLayer { throw ImportError.noTextLayer }
        return ExtractedText(text: text, pageCount: 1, usedOCR: false)
    }

    func extractWithOCR(fileAt url: URL, password: String?) async throws -> ExtractedText {
        guard let ocrText else { throw ImportError.ocrFailed }
        return ExtractedText(text: ocrText, pageCount: 1, usedOCR: true)
    }
}

@Suite("İçe aktarma hattı")
struct PipelineTests {
    static let accountID = UUID()
    static let marketID = UUID()
    static let transportID = UUID()
    static let salaryID = UUID()

    static var rules: [CategoryRuleEntity] {
        [
            CategoryRuleEntity(keyword: "MIGROS", categoryID: marketID,
                               direction: .expense, isUserDefined: false),
            CategoryRuleEntity(keyword: "SHELL", categoryID: transportID,
                               direction: .expense, isUserDefined: false),
            CategoryRuleEntity(keyword: "MAAS", categoryID: salaryID,
                               direction: .income, isUserDefined: false)
        ]
    }

    static func input(text: String, existingHashes: Set<String> = [],
                      allowOCR: Bool = false, password: String? = nil,
                      fallback: GenericColumnParser? = nil) -> ImportPipeline.Input {
        ImportPipeline.Input(
            url: URL(fileURLWithPath: "/tmp/Ziraat_ekstre_agustos.pdf"),
            password: password, allowOCR: allowOCR, fallbackParser: fallback,
            accountID: accountID, rules: rules, existingHashes: existingHashes)
    }

    @Test("Bilinen format uçtan uca onay taslağına dönüşür")
    func uctanUca() async throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))
        let draft = try await pipeline.run(Self.input(text: text))

        #expect(draft.rows.count == 6)
        #expect(draft.bankName == "Ziraat Bankası")
        #expect(draft.formatIdentifier == "ziraat.vadesiz.v1")
        #expect(draft.fileName == "Ziraat_ekstre_agustos.pdf")
        #expect(draft.duplicateCount == 0)
        // MIGROS, SHELL ve MAAS kural yakalar; kalan üçü kontrol ister.
        #expect(draft.automaticCount == 3)
        #expect(draft.reviewCount == 3)
        #expect(draft.selectedCount == 6)
    }

    @Test("Kontrol gerekenler listenin başında")
    func siralama() async throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))
        let draft = try await pipeline.run(Self.input(text: text))
        let kinds = draft.rows.map(\.kind)
        #expect(kinds.prefix(3).allSatisfy { $0 == .needsReview })
    }

    @Test("Mükerrer satır listede kalır ama seçili gelmez")
    func mukerrer() async throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let calendar = Calendar.gregorianIstanbul
        let migrosHash = DuplicateHash.make(
            date: calendar.date(from: DateComponents(year: 2026, month: 8, day: 12))!,
            amount: Money(minorUnits: 84_260), detail: "MIGROS ATASEHIR",
            calendar: calendar)

        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))
        let draft = try await pipeline.run(
            Self.input(text: text, existingHashes: [migrosHash]))

        #expect(draft.duplicateCount == 1)
        #expect(draft.selectedCount == 5)
        let duplicate = try #require(draft.rows.first { $0.kind == .duplicate })
        #expect(duplicate.detail == "MIGROS ATASEHIR")
        #expect(duplicate.isSelected == false)
    }

    @Test("C6 — şifreli PDF parola olmadan geçmez, doğru parolayla geçer")
    func sifreliPDF() async throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let extractor = StubExtractor(text: text, requiresPassword: "1234")
        let pipeline = ImportPipeline(extractor: extractor)

        await #expect(throws: ImportError.passwordProtected) {
            try await pipeline.run(Self.input(text: text))
        }
        let draft = try await pipeline.run(Self.input(text: text, password: "1234"))
        #expect(draft.rows.count == 6)
    }

    @Test("C7 — tanınmayan format ham satır önizlemesiyle hata verir")
    func taninmayanFormat() async throws {
        let text = try Fixture.text("taninmayan-banka")
        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))

        do {
            _ = try await pipeline.run(Self.input(text: text))
            Issue.record("unknownFormat bekleniyordu")
        } catch let error as ImportError {
            guard case .unknownFormat(let preview) = error else {
                Issue.record("beklenmeyen hata: \(error)")
                return
            }
            #expect(preview.count == 3)
            #expect(preview.first?.contains("2026-08-12") == true)
        }
    }

    @Test("C7 — kullanıcı sütun eşlemesiyle akış devam eder")
    func sutunEslemesiyleDevam() async throws {
        let text = try Fixture.text("taninmayan-banka")
        let fallback = GenericColumnParser(
            formatIdentifier: "xyz.genel.v1", bankName: "XYZ Finans",
            separator: "|", columns: [.date, .ignored, .detail, .amount, .balance])
        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))
        let draft = try await pipeline.run(Self.input(text: text, fallback: fallback))

        #expect(draft.rows.count == 3)
        #expect(draft.bankName == "XYZ Finans")
        // Sütun eşlemesiyle okunan satırlar tam güvenle gelmez.
        #expect(draft.automaticCount == 0)
        #expect(draft.reviewCount == 3)
    }

    @Test("C8 — metin katmanı yoksa OCR'a düşer ve tüm satırlar kontrol ister")
    func ocrDali() async throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let extractor = StubExtractor(text: "", throwsNoTextLayer: true, ocrText: text)
        let pipeline = ImportPipeline(extractor: extractor)

        await #expect(throws: ImportError.noTextLayer) {
            try await pipeline.run(Self.input(text: text, allowOCR: false))
        }

        let draft = try await pipeline.run(Self.input(text: text, allowOCR: true))
        #expect(draft.usedOCR)
        #expect(draft.rows.count == 6)
        #expect(draft.reviewCount == 6)
        #expect(draft.automaticCount == 0)
    }

    @Test("Bozuk satır taslağa kontrol maddesi olarak girer")
    func bozukSatir() async throws {
        let text = """
        T.C. ZIRAAT BANKASI A.S. HESAP OZETI
        12/08/26   MIGROS ATASEHIR                      842,60-        18.402,15
        11/08/26   SHELL OTOYOL                         BOZUK          19.244,75
        """
        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))
        let draft = try await pipeline.run(Self.input(text: text))

        #expect(draft.rows.count == 2)
        let broken = try #require(draft.rows.first { $0.amount == .zero })
        #expect(broken.kind == .needsReview)
        #expect(broken.isSelected == false)
        #expect(broken.detail.contains("SHELL"))
    }

    @Test("Onaylanan satırlar işlem varlığına çevrilir")
    func varligaCevirme() async throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))
        var draft = try await pipeline.run(Self.input(text: text))
        draft.rows[0].isSelected = false

        let builder = DraftBuilder(
            categorizer: CategorizationEngine(rules: Self.rules), accountID: Self.accountID)
        let batchID = UUID()
        let entities = builder.transactions(from: draft, importBatchID: batchID)

        #expect(entities.count == 5)
        #expect(entities.allSatisfy { $0.source == .statement })
        #expect(entities.allSatisfy { $0.importBatchID == batchID })
        #expect(entities.allSatisfy { $0.accountID == Self.accountID })
        #expect(entities.allSatisfy { $0.statementLineNumber != nil })
    }

    @Test("Net etki yalnızca seçili satırları sayar")
    func netEtki() async throws {
        let text = try Fixture.text("ziraat-vadesiz-2026-08")
        let pipeline = ImportPipeline(extractor: StubExtractor(text: text))
        let draft = try await pipeline.run(Self.input(text: text))
        // 52.400,00 gelir − (842,60 + 1.180,00 + 1.250,00 + 318,40 + 59,99)
        #expect(draft.netEffect.minorUnits == 4_874_901)
    }
}

@Suite("Kategorileme")
struct CategorizationTests {
    static let marketID = UUID()

    @Test("Türkçe karakter farkı eşleşmeyi bozmaz")
    func turkceKatlama() {
        let engine = CategorizationEngine(rules: [
            CategoryRuleEntity(keyword: "Ataşehir Migros", categoryID: Self.marketID)
        ])
        let suggestion = engine.suggest(detail: "ATASEHIR MIGROS SUBESI", direction: .expense)
        #expect(suggestion.categoryID == Self.marketID)
        #expect(suggestion.confidence > CategorizationEngine.reviewThreshold)
    }

    @Test("Yön uyuşmazsa kural uygulanmaz")
    func yonFiltresi() {
        let engine = CategorizationEngine(rules: [
            CategoryRuleEntity(keyword: "MAAS", categoryID: Self.marketID, direction: .income)
        ])
        #expect(engine.suggest(detail: "MAAS ODEMESI", direction: .expense).categoryID == nil)
        #expect(engine.suggest(detail: "MAAS ODEMESI", direction: .income).categoryID != nil)
    }

    @Test("Eşleşme yoksa öneri boş ve güven sıfır")
    func eslesmeYok() {
        let engine = CategorizationEngine(rules: [])
        let suggestion = engine.suggest(detail: "BILINMEYEN ISLEM", direction: .expense)
        #expect(suggestion.categoryID == nil)
        #expect(suggestion.confidence == 0)
    }

    @Test("Uzun ve kullanıcı tanımlı kural daha güvenli")
    func guvenSkoru() {
        let short = CategorizationEngine(rules: [
            CategoryRuleEntity(keyword: "BIM", categoryID: Self.marketID, isUserDefined: false)
        ]).suggest(detail: "BIM MARKET KADIKOY", direction: .expense)
        let long = CategorizationEngine(rules: [
            CategoryRuleEntity(keyword: "BIM MARKET KADIKOY", categoryID: Self.marketID)
        ]).suggest(detail: "BIM MARKET KADIKOY", direction: .expense)
        #expect(long.confidence > short.confidence)
    }

    @Test("Varsayılan kurallar kategori adlarıyla eşleşir")
    func varsayilanKurallar() {
        let categories = DefaultCategories.seed()
        let rules = DefaultCategoryRules.seed(categories: categories)
        #expect(rules.count > 30)
        #expect(rules.allSatisfy { rule in categories.contains { $0.id == rule.categoryID } })

        let engine = CategorizationEngine(rules: rules)
        let market = try? #require(categories.first { $0.name == "Market" })
        #expect(engine.suggest(detail: "MIGROS ATASEHIR", direction: .expense).categoryID
                == market?.id)
    }
}
