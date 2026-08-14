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

    public static func merchantKey(_ detail: String) -> String {
        let words = detail
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        guard let first = words.first else { return "" }
        // İki harfi geçmeyen ön ekler ad değildir; "A101" rakam taşıdığı için kalır.
        let isShortPrefix = first.count <= 2 && !first.contains(where: \.isNumber)
        let candidate = isShortPrefix && words.count > 1 ? words[1] : first
        return capitalize(candidate)
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
