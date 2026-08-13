import CryptoKit
import Foundation

/// Mükerrer tespiti: hash = SHA-256(normalize(tarih + tutar + açıklama)).
/// Normalizasyon şart — aynı işlem iki ekstrede farklı boşluk/büyük harf düzeniyle gelir.
public enum DuplicateHash {
    public static func make(date: Date, amount: Money, detail: String,
                            calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let payload = [
            normalizedDay(date, calendar: calendar),
            String(amount.magnitude.minorUnits),
            normalizedDetail(detail)
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Saat bilgisi atılır: aynı gün içindeki aynı işlem aynı hash'i vermeli.
    static func normalizedDay(_ date: Date, calendar: Calendar) -> String {
        var calendar = calendar
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Türkçe harfler ASCII'ye katlanır, noktalama atılır, ardışık boşluk tek boşluğa iner.
    ///
    /// Katlama şart: aynı işlem ekstrede "MIGROS ATASEHIR", kullanıcı elinde
    /// "Migros Ataşehir" olarak geçer. Katlanmazsa tr_TR büyük harf kuralı ikisini
    /// "MIGROS" ve "MİGROS" diye ayırır ve mükerrer yakalanmaz. Bu katlama yalnızca
    /// hash içindir; görüntülenen açıklama hiç değişmez.
    static let asciiFolding: [Character: Character] = [
        "İ": "I", "I": "I", "ı": "I", "i": "I",
        "Ş": "S", "ş": "S", "Ğ": "G", "ğ": "G",
        "Ç": "C", "ç": "C", "Ö": "O", "ö": "O", "Ü": "U", "ü": "U",
        "Â": "A", "â": "A", "Î": "I", "î": "I", "Û": "U", "û": "U"
    ]

    static func normalizedDetail(_ detail: String) -> String {
        let folded = String(detail.map { asciiFolding[$0] ?? $0 }).trUpper
        let stripped = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return " "
        }
        return String(stripped)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
