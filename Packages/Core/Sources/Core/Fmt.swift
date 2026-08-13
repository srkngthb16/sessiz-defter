import Foundation

/// tr_TR biçimlendirme tek kapıdan geçer: ekranda "1.234,56" ve "gg.aa.yyyy" dışında biçim olmamalı.
public enum Fmt {
    /// "₺ 48.320,75" — işaret taşımaz; +/− AmountText'in sorumluluğu.
    public static func currency(_ money: Money) -> String {
        "\(symbol(for: money.currencyCode))\u{00A0}\(amount(money))"
    }

    /// Simgesiz: "10.905,40"
    public static func amount(_ money: Money) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = TurkishLocale.locale
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: money.magnitude.decimalValue as NSDecimalNumber) ?? ""
    }

    /// "12.08.2026"
    public static func date(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("dd.MM.yyyy", calendar).string(from: date)
    }

    /// "12 Ağustos 2026 · Çarşamba" — işlem listesi gün başlığı
    public static func dayHeader(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("d MMMM yyyy · EEEE", calendar).string(from: date)
    }

    /// "12 Ağu" — satır meta bilgisi
    public static func shortDate(_ date: Date, calendar: Calendar = .current) -> String {
        formatter("d MMM", calendar).string(from: date)
    }

    /// "%91" — Türkçede yüzde işareti sayının önünde.
    public static func percent(_ ratio: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = TurkishLocale.locale
        f.maximumFractionDigits = 0
        return "%" + (f.string(from: NSNumber(value: (ratio * 100).rounded())) ?? "0")
    }

    static func symbol(for currencyCode: String) -> String {
        currencyCode == "TRY" ? "₺" : currencyCode
    }

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.locale = TurkishLocale.locale
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }
}
