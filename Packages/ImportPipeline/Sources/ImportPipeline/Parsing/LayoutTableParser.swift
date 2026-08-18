import Core
import CoreGraphics
import Domain
import Foundation

/// Bankadan bağımsız tablo okuyucu. Konumlu metni (`LayoutDocument`) alır,
/// sütunları kendisi bulur.
///
/// Neden var: her banka için elle ayrıştırıcı yazmak ölçeklenmiyor — Türkiye'de
/// onlarca banka, her birinin vadesiz/kredi kartı/kredi ekstresi ayrı düzende ve
/// banka düzenini değiştirdiğinde ayrıştırıcı bozuluyor. Kullanıcıdan ekstresini
/// istemek de mahremiyet vaadiyle çelişiyor. Sütunlar konumdan bulunursa
/// "hangi banka" sorusu ortadan kalkıyor.
///
/// Tutar ile bakiye sütununu **aritmetikle** ayırıyor: yürüyen bakiyenin iki
/// satır arasındaki farkı tutara eşitse doğru sütun bulunmuş demektir. Aynı
/// hesap yönü de veriyor — bakiye artmışsa gelir, azalmışsa gider. Bu, işaret
/// göstermeyen ekstrelerde bile doğru çalışıyor ve tahmine dayanmıyor.
public struct LayoutTableParser: Sendable {
    public let formatIdentifier = "layout.generic.v1"

    /// Aynı sütun sayılmak için sözcük ortalarının yatay yakınlığı.
    static let columnTolerance: CGFloat = 24
    /// Bakiye eşleşmesi bu oranın altındaysa sütun ilişkisi kurulmuş sayılmıyor.
    static let balanceMatchRatio = 0.6

    public init() {}

    private struct Candidate {
        let date: Date
        let detail: String
        let money: [(value: Money, isNegative: Bool, midX: CGFloat)]
        let lineNumber: Int
    }

    public func parse(_ document: LayoutDocument,
                      calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        let candidates = self.candidates(in: document, calendar: calendar)
        guard candidates.count >= 3 else { return result }

        let columns = moneyColumns(in: candidates)
        guard let amountColumn = columns.first else { return result }
        let balanceColumn = self.balanceColumn(in: candidates, amountColumn: amountColumn,
                                               columns: columns)

        var previousBalance: Money?
        for candidate in candidates {
            guard let amount = value(of: candidate, at: amountColumn) else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: candidate.lineNumber, text: candidate.detail,
                    reason: "Tutar sütununda değer yok"))
                continue
            }
            guard amount.value.minorUnits > 0, !candidate.detail.isEmpty else { continue }

            let balance = balanceColumn.flatMap { value(of: candidate, at: $0) }
            // Yön sırasıyla: bakiye farkı, tutarın işareti. Bakiye farkı en
            // güvenilir olan, çünkü ekstrenin kendi aritmetiğinden geliyor.
            let direction: TransactionDirection
            if let balance, let previous = previousBalance {
                direction = balance.value.minorUnits >= previous.minorUnits ? .income : .expense
            } else {
                direction = amount.isNegative ? .expense : .income
            }
            previousBalance = balance?.value

            result.rows.append(ParsedRow(
                date: candidate.date, detail: candidate.detail, amount: amount.value,
                direction: direction, runningBalance: balance?.value,
                lineNumber: candidate.lineNumber,
                // Sütunlar tahminle bulundu: kullanıcı onay ekranında görsün.
                confidence: balanceColumn == nil ? 0.7 : 0.9))
        }
        return result
    }

    /// Tarihi ve en az bir kuruşlu sayısı olan satırlar işlem adayıdır.
    private func candidates(in document: LayoutDocument, calendar: Calendar) -> [Candidate] {
        document.lines.enumerated().compactMap { index, line in
            var date: Date?
            var detailParts: [String] = []
            var money: [(value: Money, isNegative: Bool, midX: CGFloat)] = []

            for cell in line.cells {
                if date == nil, let parsed = StatementDateParser.parse(cell.text, calendar: calendar) {
                    date = parsed
                    continue
                }
                if AmountParser.isMoneyToken(cell.text),
                   let parsed = AmountParser.parse(cell.text) {
                    money.append((parsed.amount, parsed.isNegative, cell.midX))
                    continue
                }
                detailParts.append(cell.text)
            }

            guard let date, !money.isEmpty else { return nil }
            return Candidate(date: date, detail: detailParts.joined(separator: " ")
                .trimmingCharacters(in: .whitespaces),
                             money: money, lineNumber: index + 1)
        }
    }

    /// Para sütunlarının yatay konumları, en çok kullanılandan başlayarak.
    private func moneyColumns(in candidates: [Candidate]) -> [CGFloat] {
        var buckets: [(midX: CGFloat, count: Int)] = []
        for candidate in candidates {
            for entry in candidate.money {
                if let index = buckets.firstIndex(where: {
                    abs($0.midX - entry.midX) <= Self.columnTolerance
                }) {
                    buckets[index].count += 1
                } else {
                    buckets.append((entry.midX, 1))
                }
            }
        }
        // Soldaki sütun genelde tutar, sağdaki bakiye; ilişki aşağıda sınanıyor.
        return buckets.filter { $0.count >= candidates.count / 2 }
            .sorted { $0.midX < $1.midX }
            .map(\.midX)
    }

    /// Yürüyen bakiye sütunu: farkı tutara denk gelen sütun.
    private func balanceColumn(in candidates: [Candidate], amountColumn: CGFloat,
                               columns: [CGFloat]) -> CGFloat? {
        var best: (column: CGFloat, matches: Int)?
        for column in columns where abs(column - amountColumn) > Self.columnTolerance {
            var matches = 0
            var comparisons = 0
            var previous: Int?
            for candidate in candidates {
                guard let amount = value(of: candidate, at: amountColumn),
                      let balance = value(of: candidate, at: column) else { continue }
                let signed = balance.isNegative
                    ? -balance.value.minorUnits : balance.value.minorUnits
                if let previous {
                    comparisons += 1
                    if abs(abs(signed - previous) - amount.value.minorUnits) <= 1 { matches += 1 }
                }
                previous = signed
            }
            guard comparisons > 0,
                  Double(matches) / Double(comparisons) >= Self.balanceMatchRatio else { continue }
            if best == nil || matches > best!.matches { best = (column, matches) }
        }
        return best?.column
    }

    private func value(of candidate: Candidate,
                       at column: CGFloat) -> (value: Money, isNegative: Bool)? {
        candidate.money.first { abs($0.midX - column) <= Self.columnTolerance }
            .map { ($0.value, $0.isNegative) }
    }
}
