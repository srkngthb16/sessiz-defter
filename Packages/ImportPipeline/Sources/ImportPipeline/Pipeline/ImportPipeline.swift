import Core
import Domain
import Foundation

/// Hattın orkestrasyonu. Adımlar tasarımdaki veri akışıyla birebir:
/// dosya · metin · format · satır · normalize · mükerrer · kategori · onay.
public struct ImportPipeline: Sendable {
    public enum Stage: Int, Sendable, CaseIterable {
        case extractingText
        case detectingFormat
        case parsingRows
        case categorizing

        public var title: String {
            switch self {
            case .extractingText: "Metin çıkarılıyor"
            case .detectingFormat: "Banka formatı tanınıyor"
            case .parsingRows: "İşlemler ayrıştırılıyor"
            case .categorizing: "Kategoriler atanıyor"
            }
        }
    }

    let extractor: any TextExtracting
    let detector: BankFormatDetector
    let calendar: Calendar

    public init(extractor: any TextExtracting = PDFTextExtractor(),
                detector: BankFormatDetector = BankFormatDetector(),
                calendar: Calendar = .gregorianIstanbul) {
        self.extractor = extractor
        self.detector = detector
        self.calendar = calendar
    }

    public struct Input: Sendable {
        public let url: URL
        public let password: String?
        public let allowOCR: Bool
        /// C7 sonrası kullanıcının kurduğu eşleme.
        public let fallbackParser: GenericColumnParser?
        public let accountID: UUID
        public let rules: [CategoryRuleEntity]
        public let existingHashes: Set<String>

        public init(url: URL, password: String? = nil, allowOCR: Bool = false,
                    fallbackParser: GenericColumnParser? = nil, accountID: UUID,
                    rules: [CategoryRuleEntity], existingHashes: Set<String>) {
            self.url = url
            self.password = password
            self.allowOCR = allowOCR
            self.fallbackParser = fallbackParser
            self.accountID = accountID
            self.rules = rules
            self.existingHashes = existingHashes
        }
    }

    public struct Output: Sendable {
        public let draft: ImportDraft
        public let report: ParseReport
        /// Ham metin yalnızca bellekte tutulur; kullanıcı isterse anonimleştirilip
        /// paylaşılır, hiçbir yere kendiliğinden yazılmaz.
        public let extractedText: String
    }

    public func run(_ input: Input) async throws -> ImportDraft {
        try await runDetailed(input).draft
    }

    /// Kart ekstresi mi hesap ekstresi mi: yeni hesap açılırken türü belirliyor.
    /// Biçim kimliğinden okunuyor, ayrı bir alan tutulmuyor — kimlik zaten
    /// ayrıştırıcıyla birlikte değişen tek şey.
    static func accountKind(forFormat identifier: String) -> AccountKind {
        let card = ["krediKarti", "paraf", "bonus"]
        return card.contains(where: identifier.contains) ? .creditCard : .checking
    }

    public func runDetailed(_ input: Input) async throws -> Output {
        let extracted: ExtractedText
        do {
            extracted = try extractor.extract(fileAt: input.url, password: input.password)
        } catch ImportError.noTextLayer where input.allowOCR {
            extracted = try await extractor.extractWithOCR(fileAt: input.url,
                                                           password: input.password)
        }

        let parser: any StatementParsing
        if let detected = detector.detect(in: extracted.text) {
            parser = detected
        } else if let fallback = input.fallbackParser {
            parser = fallback
        } else {
            throw ImportError.unknownFormat(preview: Self.preview(of: extracted.text))
        }

        let result = parser.parse(extracted.text, calendar: calendar)
        let builder = DraftBuilder(
            categorizer: CategorizationEngine(rules: input.rules),
            accountID: input.accountID)
        var draft = builder.build(
            from: result,
            fileName: input.url.lastPathComponent,
            bankName: parser.bankName,
            existingHashes: input.existingHashes,
            usedOCR: extracted.usedOCR,
            calendar: calendar)
        // Banka adı ve son dört hane ekstrenin içinde hazır duruyor; kullanıcıya
        // "hangi hesap" diye sormak yerine buradan çıkarılıyor.
        draft.maskedNumber = AccountHint.maskedNumber(in: extracted.text)
        draft.accountKind = Self.accountKind(forFormat: result.formatIdentifier)
        return Output(
            draft: draft,
            report: ParseReport.make(from: result, text: extracted.text,
                                     bankName: parser.bankName, calendar: calendar),
            extractedText: extracted.text)
    }

    /// C7 ekranındaki "Ham satır önizlemesi" — kullanıcı sütunları eşlerken görür.
    static func preview(of text: String, limit: Int = 5) -> [String] {
        text.split(separator: "\n")
            .map { line in TextNormalizer.collapseSpaces(String(line)) }
            .filter { line in line.count > 12 && line.contains(where: \.isNumber) }
            .prefix(limit)
            .map { line in line }
    }
}
