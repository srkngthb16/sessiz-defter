import Foundation

public enum TurkishLocale {
    public static let identifier = "tr_TR"
    public static let locale = Locale(identifier: identifier)
}

// Türkçe küçük/büyük harf dönüşümü varsayılan locale ile yapılırsa
// "İstanbul".lowercased() → "i̇stanbul" olur. Bu iki alan onu önler.
extension String {
    public var trUpper: String { uppercased(with: TurkishLocale.locale) }
    public var trLower: String { lowercased(with: TurkishLocale.locale) }
}
