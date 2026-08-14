import Core
import Domain
import Foundation

/// Parser çıktısı. Henüz Domain varlığı değil: hesap eşleşmesi, kategori ve
/// mükerrer kontrolü sonraki adımlarda yapılır.
public struct ParsedRow: Hashable, Sendable {
    public var date: Date
    public var detail: String
    /// Daima pozitif; yön ayrı alanda.
    public var amount: Money
    public var direction: TransactionDirection
    public var runningBalance: Money?
    /// Kaynak metindeki satır numarası — D5 "satır 18" bilgisi buradan gelir.
    public var lineNumber: Int
    /// Ayrıştırma güveni (0...1). 1'den küçük her satır onay ekranında işaretli gelir.
    public var confidence: Double

    public init(date: Date, detail: String, amount: Money,
                direction: TransactionDirection, runningBalance: Money? = nil,
                lineNumber: Int, confidence: Double = 1.0) {
        self.date = date
        self.detail = detail
        self.amount = amount.magnitude
        self.direction = direction
        self.runningBalance = runningBalance
        self.lineNumber = lineNumber
        self.confidence = confidence
    }
}

/// Ayrıştırılamayan satır atılmaz: "kontrol gerekiyor" olarak onay ekranına düşer.
public struct UnparsedRow: Hashable, Sendable {
    public let lineNumber: Int
    public let text: String
    public let reason: String

    public init(lineNumber: Int, text: String, reason: String) {
        self.lineNumber = lineNumber
        self.text = text
        self.reason = reason
    }
}

public struct ParseResult: Hashable, Sendable {
    public var rows: [ParsedRow]
    public var unparsed: [UnparsedRow]
    public var formatIdentifier: String

    public init(rows: [ParsedRow] = [], unparsed: [UnparsedRow] = [],
                formatIdentifier: String) {
        self.rows = rows
        self.unparsed = unparsed
        self.formatIdentifier = formatIdentifier
    }

    public var totalAmount: Money {
        rows.reduce(Money.zero) { $0 + $1.amount }
    }

    public var dateRange: ClosedRange<Date>? {
        guard let first = rows.map(\.date).min(), let last = rows.map(\.date).max()
        else { return nil }
        return first...last
    }
}
