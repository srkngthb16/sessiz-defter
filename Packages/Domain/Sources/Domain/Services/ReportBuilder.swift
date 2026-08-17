import Core
import Foundation

/// E3 — trend grafiğinin tek noktası.
public struct PeriodPoint: Identifiable, Hashable, Sendable {
    public let interval: DateInterval
    public let summary: PeriodSummary
    /// "Ağu" · "Ç3" · "2026"
    public let label: String

    public var id: Date { interval.start }
    public var income: Money { summary.income }
    public var expense: Money { summary.expense }
    public var net: Money { summary.net }

    public init(interval: DateInterval, summary: PeriodSummary, label: String) {
        self.interval = interval
        self.summary = summary
        self.label = label
    }
}

/// "Market +%14" — iki dönem arasındaki kategori değişimi.
public struct CategoryComparison: Identifiable, Hashable, Sendable {
    public let categoryID: UUID?
    public let current: Money
    public let previous: Money

    public var id: UUID { categoryID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }

    public init(categoryID: UUID?, current: Money, previous: Money) {
        self.categoryID = categoryID
        self.current = current
        self.previous = previous
    }

    /// Önceki dönem sıfırsa oran tanımsızdır: "yeni" olarak okunmalı, %∞ değil.
    public var changeRatio: Double? {
        guard previous.minorUnits > 0 else { return nil }
        return Double(current.minorUnits - previous.minorUnits) / Double(previous.minorUnits)
    }

    public var isIncrease: Bool { current > previous }
}

/// "1 Migros · 7 işlem · 4.980,20"
/// Hesap (banka) bazlı dönem toplamı. Kullanıcı her bankanın gelirini ve giderini
/// ayrı görmek istiyor: tek toplam, iki bankası olan biri için okunmaz oluyor.
///
/// Transfer sayısı ayrı tutuluyor ama net etkiye girmiyor — hesaplar arası
/// aktarma varlık yaratmıyor, yalnız yer değiştiriyor.
public struct AccountTotal: Identifiable, Hashable, Sendable {
    public let accountID: UUID
    public let name: String
    public let maskedNumber: String?
    public let income: Money
    public let expense: Money
    public let transferCount: Int

    public var id: UUID { accountID }
    public var net: Money { income - expense }

    public init(accountID: UUID, name: String, maskedNumber: String?,
                income: Money, expense: Money, transferCount: Int) {
        self.accountID = accountID
        self.name = name
        self.maskedNumber = maskedNumber
        self.income = income
        self.expense = expense
        self.transferCount = transferCount
    }
}

public struct MerchantTotal: Identifiable, Hashable, Sendable {
    public let name: String
    public let transactionCount: Int
    public let total: Money

    public var id: String { name }

    public init(name: String, transactionCount: Int, total: Money) {
        self.name = name
        self.transactionCount = transactionCount
        self.total = total
    }
}

public enum ReportScale: String, CaseIterable, Sendable, Identifiable {
    case month, quarter, year

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .month: "Ay"
        case .quarter: "Çeyrek"
        case .year: "Yıl"
        }
    }

    /// Trend grafiğinde kaç nokta gösterilir.
    public var pointCount: Int {
        switch self {
        case .month: 6
        case .quarter: 4
        case .year: 3
        }
    }
}

public struct ReportBuilder: Sendable {
    let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func trend(
        _ transactions: [TransactionEntity],
        scale: ReportScale,
        endingAt date: Date
    ) -> [PeriodPoint] {
        (0..<scale.pointCount).reversed().compactMap { offset in
            guard let interval = self.interval(scale: scale, offset: offset, from: date)
            else { return nil }
            let rows = transactions.filter { interval.contains($0.date) }
            return PeriodPoint(interval: interval,
                               summary: PeriodSummary.make(from: rows),
                               label: label(for: interval, scale: scale))
        }
    }

    func interval(scale: ReportScale, offset: Int, from date: Date) -> DateInterval? {
        switch scale {
        case .month:
            guard let anchor = calendar.date(byAdding: .month, value: -offset, to: date)
            else { return nil }
            return Period.month(containing: anchor, calendar: calendar)
        case .quarter:
            guard let anchor = calendar.date(byAdding: .month, value: -offset * 3, to: date),
                  let start = quarterStart(of: anchor),
                  let end = calendar.date(byAdding: DateComponents(month: 3, second: -1),
                                          to: start)
            else { return nil }
            return DateInterval(start: start, end: end)
        case .year:
            guard let anchor = calendar.date(byAdding: .year, value: -offset, to: date),
                  let start = calendar.date(from: calendar.dateComponents([.year], from: anchor)),
                  let end = calendar.date(byAdding: DateComponents(year: 1, second: -1),
                                          to: start)
            else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    func quarterStart(of date: Date) -> Date? {
        let month = calendar.component(.month, from: date)
        let firstMonth = ((month - 1) / 3) * 3 + 1
        var components = calendar.dateComponents([.year], from: date)
        components.month = firstMonth
        components.day = 1
        return calendar.date(from: components)
    }

    func label(for interval: DateInterval, scale: ReportScale) -> String {
        let formatter = DateFormatter()
        formatter.locale = TurkishLocale.locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch scale {
        case .month:
            formatter.dateFormat = "MMM"
            return formatter.string(from: interval.start)
        case .quarter:
            let quarter = (calendar.component(.month, from: interval.start) - 1) / 3 + 1
            return "Ç\(quarter)"
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: interval.start)
        }
    }

    /// Kategori bazlı dönem karşılaştırması.
    public func comparison(
        _ transactions: [TransactionEntity],
        current: DateInterval,
        previous: DateInterval,
        limit: Int = 5
    ) -> [CategoryComparison] {
        func totals(_ interval: DateInterval) -> [UUID?: Int] {
            var result: [UUID?: Int] = [:]
            for row in transactions where row.direction == .expense && interval.contains(row.date) {
                result[row.categoryID, default: 0] += row.amount.minorUnits
            }
            return result
        }

        let currentTotals = totals(current)
        let previousTotals = totals(previous)
        let keys = Set(currentTotals.keys).union(previousTotals.keys)

        return keys
            .map { key in
                CategoryComparison(
                    categoryID: key,
                    current: Money(minorUnits: currentTotals[key] ?? 0),
                    previous: Money(minorUnits: previousTotals[key] ?? 0))
            }
            // Bu dönemde en çok harcanan önce; oran değil tutar sıralar, küçük
            // kalemlerdeki büyük yüzdeler listeyi ele geçirmesin.
            .sorted { $0.current > $1.current }
            .prefix(limit)
            .map { $0 }
    }

    /// "En çok harcanan yerler". İşyeri adı açıklamanın ilk anlamlı kelimesinden
    /// türetilir: "MIGROS ATASEHIR" ve "MIGROS KADIKOY" aynı yerdir.
    /// Hesap bazlı dönem toplamları. Silinmiş hesaba bağlı işlem kalmışsa o kimlik
    /// listede karşılık bulmuyor ve atlanıyor: adı olmayan bir satır çizmek
    /// toplamı okunmaz yapardı.
    public func accountTotals(
        _ transactions: [TransactionEntity],
        accounts: [AccountEntity],
        in interval: DateInterval
    ) -> [AccountTotal] {
        var totals: [UUID: (income: Int, expense: Int, transfers: Int)] = [:]
        for row in transactions where interval.contains(row.date) {
            var entry = totals[row.accountID] ?? (0, 0, 0)
            switch row.direction {
            case .income: entry.income += row.amount.minorUnits
            case .expense: entry.expense += row.amount.minorUnits
            case .transfer: entry.transfers += 1
            }
            totals[row.accountID] = entry
        }

        return accounts.compactMap { account -> AccountTotal? in
            guard let entry = totals[account.id] else { return nil }
            return AccountTotal(
                accountID: account.id, name: account.name,
                maskedNumber: account.maskedNumber,
                income: Money(minorUnits: entry.income),
                expense: Money(minorUnits: entry.expense),
                transferCount: entry.transfers)
        }
        // Gideri en büyük hesap üstte: bütçe okuması oradan başlıyor.
        .sorted { $0.expense > $1.expense }
    }

    public func topMerchants(
        _ transactions: [TransactionEntity],
        in interval: DateInterval,
        limit: Int = 3
    ) -> [MerchantTotal] {
        var totals: [String: (count: Int, sum: Int)] = [:]
        for row in transactions
        where row.direction == .expense && interval.contains(row.date) {
            let key = Self.merchantKey(row.detail)
            guard !key.isEmpty else { continue }
            let existing = totals[key] ?? (0, 0)
            totals[key] = (existing.count + 1, existing.sum + row.amount.minorUnits)
        }
        return totals
            .map { MerchantTotal(name: $0.key, transactionCount: $0.value.count,
                                 total: Money(minorUnits: $0.value.sum)) }
            .sorted { $0.total > $1.total }
            .prefix(limit)
            .map { $0 }
    }

    /// Gerçek ekstrelerde açıklama işyeri adıyla başlamıyor: önünde tarih, işlem
    /// kodu, IBAN ya da "ALISVERIS/SNFT 5262901589985507 PN 019366" gibi bankaya
    /// ait alanlar oluyor. İlk sözcüğü almak raporda "27" ve "9876549888661497qr"
    /// gibi başlıklar üretiyordu; bu yüzden anlamsız sözcükler eleniyor.
    public static func merchantKey(_ detail: String) -> String {
        let words = detail
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        // Ay adları tarihin parçası, işyeri değil.
        let months = ["OCAK", "SUBAT", "MART", "NISAN", "MAYIS", "HAZIRAN", "TEMMUZ",
                      "AGUSTOS", "EYLUL", "EKIM", "KASIM", "ARALIK"]
        // Banka alan adları her satırda tekrar ediyor ve işyerini gölgeliyor.
        let noise = ["ALISVERIS", "HBPOS", "SNFT", "PN", "POS", "ISLEM", "ODEME",
                     "TRANSFER", "HESAPLAR", "ARASI", "GIDEN", "GELEN", "FAST",
                     "TARAFINDAN", "GONDERILEN", "DAN", "DEN", "TL", "KART",
                     "KARTI", "KREDI", "TAKSIT", "UCRET", "UCRETI", "DEVIR"]

        let meaningful = words.first { word in
            let folded = CategorizationEngine.fold(word)
            guard word.contains(where: \.isLetter), word.count > 2 else { return false }
            guard !months.contains(folded), !noise.contains(folded) else { return false }
            // IBAN parçası: "TR51", "TR30". Marka adı gibi görünüyor ama değil.
            if folded.hasPrefix("TR"), folded.dropFirst(2).allSatisfy(\.isNumber) { return false }
            // Uzun rakam öbekleri kart ve referans numarası ("9876549888661497qr").
            // Kısa rakam kuyruğu ada ait olabiliyor, o yüzden eşik var: "A101" kalır.
            return word.filter(\.isNumber).count <= 8
        }
        // Hiçbir sözcük anlamlı çıkmazsa bile kart numarası başlık olmasın:
        // önce harf taşıyan ilk sözcüğe düşülüyor.
        let fallback = words.first { $0.contains(where: \.isLetter) } ?? words.first
        return capitalize(meaningful ?? fallback ?? "")
    }

    /// Ekstre metni çoğunlukla ASCII gelir: "MIGROS". tr_TR kuralıyla küçültmek
    /// bunu "Mıgros" yapar. Türkçeye özgü harf taşımayan metin en_US ile,
    /// taşıyan metin tr_TR ile dönüştürülür.
    static func capitalize(_ word: String) -> String {
        let turkishOnly = CharacterSet(charactersIn: "ğĞşŞıİçÇöÖüÜ")
        let usesTurkishLetters = word.unicodeScalars.contains { turkishOnly.contains($0) }
        let locale = usesTurkishLetters ? TurkishLocale.locale : Locale(identifier: "en_US")
        guard let firstCharacter = word.first else { return "" }
        return String(firstCharacter).uppercased(with: locale)
            + word.dropFirst().lowercased(with: locale)
    }
}
