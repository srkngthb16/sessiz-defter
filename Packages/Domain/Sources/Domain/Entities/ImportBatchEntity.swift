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
        usedOCR: Bool = false
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
    }
}
