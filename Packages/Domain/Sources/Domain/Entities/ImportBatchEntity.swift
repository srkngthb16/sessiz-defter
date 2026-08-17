import Foundation

public struct ImportBatchEntity: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var fileName: String
    public var importedAt: Date
    public var periodStart: Date?
    public var periodEnd: Date?
    public var addedCount: Int
    public var skippedDuplicateCount: Int
    public var manuallyRecategorizedCount: Int
    public var bankFormatIdentifier: String?
    /// Kaynak PDF kasada tutuldu mu. Varsayılan davranış: içe aktarma sonrası silinir.
    public var sourceFileRetained: Bool
    /// Metin katmanı yoktu, Vision OCR kullanıldı — tüm satırlar "kontrol gerekiyor" gelir.
    public var usedOCR: Bool
    /// İçe aktarma iki aşamalı yazılıyor: önce bu kayıt `false` ile, sonra
    /// işlemler, en son `true`. Uygulama arada ölürse yarım kalan iş buradan
    /// anlaşılıyor — 10.000 işlemi taramaya gerek kalmadan.
    public var isComplete: Bool

    public init(
        id: UUID = UUID(),
        fileName: String,
        importedAt: Date = Date(),
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        addedCount: Int = 0,
        skippedDuplicateCount: Int = 0,
        manuallyRecategorizedCount: Int = 0,
        bankFormatIdentifier: String? = nil,
        sourceFileRetained: Bool = false,
        usedOCR: Bool = false,
        isComplete: Bool = true
    ) {
        self.id = id
        self.fileName = fileName
        self.importedAt = importedAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.addedCount = addedCount
        self.skippedDuplicateCount = skippedDuplicateCount
        self.manuallyRecategorizedCount = manuallyRecategorizedCount
        self.bankFormatIdentifier = bankFormatIdentifier
        self.sourceFileRetained = sourceFileRetained
        self.usedOCR = usedOCR
        self.isComplete = isComplete
    }

    /// Eski yedeklerde bu alan yok; okunurken tamamlanmış sayılıyor.
    enum CodingKeys: String, CodingKey {
        case id, fileName, importedAt, periodStart, periodEnd, addedCount
        case skippedDuplicateCount, manuallyRecategorizedCount, bankFormatIdentifier
        case sourceFileRetained, usedOCR, isComplete
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
        periodStart = try container.decodeIfPresent(Date.self, forKey: .periodStart)
        periodEnd = try container.decodeIfPresent(Date.self, forKey: .periodEnd)
        addedCount = try container.decode(Int.self, forKey: .addedCount)
        skippedDuplicateCount = try container.decode(Int.self, forKey: .skippedDuplicateCount)
        manuallyRecategorizedCount = try container.decode(
            Int.self, forKey: .manuallyRecategorizedCount)
        bankFormatIdentifier = try container.decodeIfPresent(
            String.self, forKey: .bankFormatIdentifier)
        sourceFileRetained = try container.decode(Bool.self, forKey: .sourceFileRetained)
        usedOCR = try container.decode(Bool.self, forKey: .usedOCR)
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? true
    }
}
