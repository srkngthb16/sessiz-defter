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

    /// Tutarın işaret durumu — okunuşta "eksi"/"artı" sözcüğü buradan gelir.
    public enum SpokenSign: Sendable {
        /// Bakiye gibi yönsüz tutar: işaret değerin kendisinden okunur.
        case fromValue
        case income
        case expense
        case none
    }

    /// "eksi 842 lira 60 kuruş" — VoiceOver okunuşu.
    ///
    /// Ekrandaki "₺ 842,60" biçimi seslendirmede işe yaramıyor: simgenin ve
    /// virgülün okunuşu cihaza göre değişiyor, "sekiz yüz kırk iki virgül altmış"
    /// tutarı para gibi duyurmuyor. Kuruş sıfırsa hiç okunmaz — liste taramasında
    /// her satırda "sıfır kuruş" duymak yoruyor.
    public static func spoken(_ money: Money, sign: SpokenSign = .fromValue) -> String {
        let minorUnits = abs(money.minorUnits)
        let major = minorUnits / 100
        let minor = minorUnits % 100

        let words = unitWords(for: money.currencyCode)
        var parts: [String] = []

        switch sign {
        case .fromValue: if money.isNegative { parts.append("eksi") }
        case .expense: parts.append("eksi")
        case .income: parts.append("artı")
        case .none: break
        }

        parts.append("\(grouped(major)) \(words.major)")
        if minor > 0 { parts.append("\(minor) \(words.minor)") }
        return parts.joined(separator: " ")
    }

    /// "yüzde 91" — sayının önündeki "%" bazı seslerde hiç okunmuyor.
    public static func spokenPercent(_ ratio: Double) -> String {
        "yüzde \(Int((ratio * 100).rounded()))"
    }

    private static func unitWords(for currencyCode: String) -> (major: String, minor: String) {
        currencyCode == "TRY" ? ("lira", "kuruş") : (currencyCode, "cent")
    }

    private static func grouped(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = TurkishLocale.locale
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
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
