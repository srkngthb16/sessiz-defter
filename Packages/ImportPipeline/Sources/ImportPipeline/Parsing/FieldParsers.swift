import Core
import Domain
import Foundation

/// Tutar metni tam sayı kuruşa çevrilir. Locale'e güvenilmez: ekstre metni
/// telefonun bölge ayarından bağımsız olarak Türk biçimindedir.
public enum AmountParser {
    /// "1.180,00-" · "842,60" · "-180,00 TL" · "52.400,00+" · "18402.15"
    public static func parse(_ raw: String) -> (amount: Money, isNegative: Bool)? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        text = text.replacingOccurrences(of: "TL", with: "")
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !text.isEmpty else { return nil }

        var isNegative = false
        // İşaret önde ya da sonda olabilir; ekstrelerde sondaki eksi yaygın.
        for marker in ["-", "\u{2212}"] {
            if text.hasSuffix(marker) {
                isNegative = true
                text.removeLast()
            }
            if text.hasPrefix(marker) {
                isNegative = true
                text.removeFirst()
            }
        }
        if text.hasSuffix("+") { text.removeLast() }
        if text.hasPrefix("+") { text.removeFirst() }
        guard !text.isEmpty else { return nil }

        let minorUnits: Int
        if let comma = text.lastIndex(of: ","), let dot = text.lastIndex(of: "."), dot > comma {
            // İngiliz biçimi: "2,075.37". Halkbank Paraf ekstresi böyle yazıyor —
            // virgül binlik, nokta ondalık. Türk biçimiyle karışmaması için ayraç
            // sırasına bakılıyor, locale tahminine değil.
            let whole = text[text.startIndex..<dot].replacingOccurrences(of: ",", with: "")
            let fraction = String(text[text.index(after: dot)...])
            guard let value = normalize(whole: whole, fraction: fraction) else { return nil }
            minorUnits = value
        } else if let separatorIndex = text.lastIndex(of: ",") {
            // Virgül ondalık: nokta binlik ayracıdır.
            let whole = text[text.startIndex..<separatorIndex]
                .replacingOccurrences(of: ".", with: "")
            let fraction = String(text[text.index(after: separatorIndex)...])
            guard let value = normalize(whole: whole, fraction: fraction) else { return nil }
            minorUnits = value
        } else if let separatorIndex = text.lastIndex(of: "."),
                  text.distance(from: text.index(after: separatorIndex),
                                to: text.endIndex) == 2,
                  !text.contains(",") {
            // Nokta ondalık (makine biçimi): "18402.15"
            let whole = String(text[text.startIndex..<separatorIndex])
            let fraction = String(text[text.index(after: separatorIndex)...])
            guard let value = normalize(whole: whole, fraction: fraction) else { return nil }
            minorUnits = value
        } else {
            let whole = text.replacingOccurrences(of: ".", with: "")
            guard whole.allSatisfy(\.isNumber), let value = Int(whole) else { return nil }
            minorUnits = value * 100
        }
        return (Money(minorUnits: minorUnits), isNegative)
    }

    private static func normalize(whole: String, fraction: String) -> Int? {
        guard whole.allSatisfy(\.isNumber) || whole.isEmpty,
              fraction.allSatisfy(\.isNumber), fraction.count <= 2 else { return nil }
        let padded = fraction.count == 1 ? fraction + "0" : fraction
        let wholeValue = whole.isEmpty ? 0 : Int(whole)
        guard let wholeValue, let fractionValue = Int(padded.isEmpty ? "0" : padded)
        else { return nil }
        return wholeValue * 100 + fractionValue
    }
}

/// Ekstre tarihleri sabit desenlidir; DateFormatter locale'i tr_TR'ye sabitlenir.
public enum StatementDateParser {
    /// "16 Haziran 2026" biçimi Garanti Bonus ekstresinden geliyor; ay adı tr_TR
    /// locale'iyle çözülüyor, o yüzden ayrı bir tablo gerekmiyor.
    public static let formats = ["dd/MM/yy", "dd.MM.yyyy", "dd/MM/yyyy",
                                 "dd.MM.yy", "yyyy-MM-dd", "d MMMM yyyy",
                                 // Halkbank hesap özeti: "11-03-2026".
                                 "dd-MM-yyyy"]

    public static func parse(_ raw: String, calendar: Calendar = .gregorianIstanbul) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = TurkishLocale.locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

extension Calendar {
    public static var gregorianIstanbul: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        return calendar
    }
}
