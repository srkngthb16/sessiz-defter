import Foundation

public enum TurkishLocale {
    /// Türkçe harflerin ASCII karşılıkları. Hem mükerrer hash'i hem de kullanıcı
    /// onayı gibi metin karşılaştırmalarını besliyor: iki yerde ayrı tablo
    /// tutmak birinin güncellenip diğerinin unutulması demekti.
    public static let asciiFolding: [Character: Character] = [
        "İ": "I", "I": "I", "ı": "I", "i": "I",
        "Ş": "S", "ş": "S", "Ğ": "G", "ğ": "G",
        "Ç": "C", "ç": "C", "Ö": "O", "ö": "O", "Ü": "U", "ü": "U",
        "Â": "A", "â": "A", "Î": "I", "î": "I", "Û": "U", "û": "U"
    ]

    public static let identifier = "tr_TR"
    public static let locale = Locale(identifier: identifier)
}

// Türkçe küçük/büyük harf dönüşümü varsayılan locale ile yapılırsa
// "İstanbul".lowercased() → "i̇stanbul" olur. Bu iki alan onu önler.
extension String {
    public var trUpper: String { uppercased(with: TurkishLocale.locale) }

    /// Türkçe harfleri ASCII'ye katlanmış büyük harf: "sil", "SIL", "SİL", "sıl"
    /// hepsi "SIL" olur.
    ///
    /// Klavye ve otomatik büyük harf kuralları "i" harfini cihaza göre "I" ya da
    /// "İ" yapıyor; kullanıcının hangi harfin üretileceğine karar verme şansı yok.
    /// Metin karşılaştırması bunu bilerek yapılmalı.
    public var trFoldedUpper: String {
        String(map { TurkishLocale.asciiFolding[$0] ?? $0 }).trUpper
    }
    public var trLower: String { lowercased(with: TurkishLocale.locale) }
}
