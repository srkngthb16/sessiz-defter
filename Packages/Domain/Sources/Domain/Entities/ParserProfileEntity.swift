import Foundation

/// Tanınmayan formatta kullanıcı sütunları bir kez eşler (C7); eşleme cihazda saklanır
/// ve sonraki ekstrelerde otomatik kullanılır.
public enum ColumnRole: String, Codable, Sendable, CaseIterable {
    case date
    case detail
    case amount
    case balance
    case ignored
}

public struct ParserProfileEntity: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var bankName: String
    public var formatIdentifier: String
    /// Başlık/altbilgi imzaları — BankFormatDetector bunlarla eşleştirir.
    public var signatures: [String]
    public var columnMapping: [ColumnRole]
    public var isUserDefined: Bool
    public var createdAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        bankName: String,
        formatIdentifier: String,
        signatures: [String] = [],
        columnMapping: [ColumnRole] = [],
        isUserDefined: Bool = true,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.bankName = bankName
        self.formatIdentifier = formatIdentifier
        self.signatures = signatures
        self.columnMapping = columnMapping
        self.isUserDefined = isUserDefined
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}
