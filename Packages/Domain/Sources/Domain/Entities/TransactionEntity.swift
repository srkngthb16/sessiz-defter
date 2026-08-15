import Core
import Foundation

/// Yön renkle değil, üç katmanla kodlanır (işaret + ikon + renk); bu yüzden
/// yön tutarın işaretinden değil ayrı bir alandan okunur. Tutar daima pozitif tutulur.
public enum TransactionDirection: String, Codable, Sendable, CaseIterable {
    case income
    case expense
    case transfer

    /// Tutarın önüne gelen işaret. Transfer işaretsizdir.
    public var signPrefix: String {
        switch self {
        case .income: "+"
        case .expense: "\u{2212}"   // U+2212 MINUS SIGN, tire değil
        case .transfer: ""
        }
    }

    public var symbolName: String {
        switch self {
        case .income: "arrow.down.left"
        case .expense: "arrow.up.right"
        case .transfer: "arrow.left.arrow.right"
        }
    }
}

public enum TransactionSource: String, Codable, Sendable {
    case manual
    case statement
}

public struct TransactionEntity: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var date: Date
    /// Daima pozitif; yön `direction` alanında.
    public var amount: Money
    public var direction: TransactionDirection
    public var detail: String
    public var categoryID: UUID?
    public var accountID: UUID
    public var counterpartAccountID: UUID?
    public var note: String?
    public var tags: [String]
    public var source: TransactionSource
    public var importBatchID: UUID?
    public var statementLineNumber: Int?
    /// normalize(tarih + tutar + açıklama) SHA-256 — mükerrer tespitinin tek dayanağı.
    public var duplicateHash: String
    /// Otomatik kategorilemenin güveni (0...1). Elle atanmışsa nil.
    public var categoryConfidence: Double?
    public var needsReview: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        amount: Money,
        direction: TransactionDirection,
        detail: String,
        categoryID: UUID? = nil,
        accountID: UUID,
        counterpartAccountID: UUID? = nil,
        note: String? = nil,
        tags: [String] = [],
        source: TransactionSource = .manual,
        importBatchID: UUID? = nil,
        statementLineNumber: Int? = nil,
        duplicateHash: String? = nil,
        categoryConfidence: Double? = nil,
        needsReview: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amount = amount.magnitude
        self.direction = direction
        self.detail = detail
        self.categoryID = categoryID
        self.accountID = accountID
        self.counterpartAccountID = counterpartAccountID
        self.note = note
        self.tags = tags
        self.source = source
        self.importBatchID = importBatchID
        self.statementLineNumber = statementLineNumber
        self.duplicateHash = duplicateHash
            ?? DuplicateHash.make(date: date, amount: amount, detail: detail)
        self.categoryConfidence = categoryConfidence
        self.needsReview = needsReview
        self.createdAt = createdAt
    }

    /// Bakiyeye etkisi: gider negatif, transfer nötr (iki hesap arasında yer değiştirir).
    public var signedAmount: Money {
        switch direction {
        case .income: amount
        case .expense: -amount
        case .transfer: .zero
        }
    }
}
