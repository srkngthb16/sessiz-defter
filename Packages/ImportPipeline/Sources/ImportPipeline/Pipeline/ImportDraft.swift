import Core
import Domain
import Foundation

/// C3 onay ekranının veri modeli. Hiçbir satır sessizce atılmaz: mükerrer olanlar
/// varsayılan olarak seçilmez ama listede kalır.
public struct ImportDraftRow: Identifiable, Hashable, Sendable {
    public enum Kind: Sendable, Hashable {
        case automatic      // güvenle kategorilendi
        case needsReview    // düşük güven ya da ayrıştırma sorunu
        case duplicate      // aynı hash zaten kayıtlı
    }

    public let id: UUID
    public var date: Date
    public var detail: String
    public var amount: Money
    public var direction: TransactionDirection
    public var categoryID: UUID?
    public var confidence: Double
    public var kind: Kind
    public var isSelected: Bool
    public var lineNumber: Int
    public var duplicateHash: String
    /// Kullanıcı kategoriyi elle değiştirdiyse özet sayacında görünür (C5).
    public var wasRecategorized: Bool

    public init(id: UUID = UUID(), date: Date, detail: String, amount: Money,
                direction: TransactionDirection, categoryID: UUID?, confidence: Double,
                kind: Kind, isSelected: Bool, lineNumber: Int, duplicateHash: String,
                wasRecategorized: Bool = false) {
        self.id = id
        self.date = date
        self.detail = detail
        self.amount = amount
        self.direction = direction
        self.categoryID = categoryID
        self.confidence = confidence
        self.kind = kind
        self.isSelected = isSelected
        self.lineNumber = lineNumber
        self.duplicateHash = duplicateHash
        self.wasRecategorized = wasRecategorized
    }
}

public struct ImportDraft: Sendable {
    public var fileName: String
    public var formatIdentifier: String
    public var bankName: String
    public var rows: [ImportDraftRow]
    public var usedOCR: Bool

    public init(fileName: String, formatIdentifier: String, bankName: String,
                rows: [ImportDraftRow], usedOCR: Bool = false) {
        self.fileName = fileName
        self.formatIdentifier = formatIdentifier
        self.bankName = bankName
        self.rows = rows
        self.usedOCR = usedOCR
    }

    public var automaticCount: Int { rows.filter { $0.kind == .automatic }.count }
    public var reviewCount: Int { rows.filter { $0.kind == .needsReview }.count }
    public var duplicateCount: Int { rows.filter { $0.kind == .duplicate }.count }
    public var selectedCount: Int { rows.filter(\.isSelected).count }

    public var dateRange: ClosedRange<Date>? {
        guard let low = rows.map(\.date).min(), let high = rows.map(\.date).max()
        else { return nil }
        return low...high
    }

    /// C5 "Yeni net etki" — seçili satırların gelir eksi gider toplamı.
    public var netEffect: Money {
        rows.filter(\.isSelected).reduce(Money.zero) { running, row in
            switch row.direction {
            case .income: running + row.amount
            case .expense: running - row.amount
            case .transfer: running
            }
        }
    }
}
