import Foundation

/// Tutarlar kuruş (minor unit) cinsinden tam sayı tutulur.
/// Double kullanılmaz: biriktirme hatası para toplamında kabul edilemez.
public struct Money: Hashable, Sendable, Comparable, Codable {
    public let minorUnits: Int
    public let currencyCode: String

    public init(minorUnits: Int, currencyCode: String = "TRY") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    public static let zero = Money(minorUnits: 0)

    public var decimalValue: Decimal { Decimal(minorUnits) / 100 }
    public var isNegative: Bool { minorUnits < 0 }
    public var magnitude: Money { Money(minorUnits: abs(minorUnits), currencyCode: currencyCode) }

    public static func < (lhs: Money, rhs: Money) -> Bool { lhs.minorUnits < rhs.minorUnits }

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Farklı para birimleri toplanamaz")
        return Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "Farklı para birimleri çıkarılamaz")
        return Money(minorUnits: lhs.minorUnits - rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    public static prefix func - (value: Money) -> Money {
        Money(minorUnits: -value.minorUnits, currencyCode: value.currencyCode)
    }
}
