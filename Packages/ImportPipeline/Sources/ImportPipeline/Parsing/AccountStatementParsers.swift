import Core
import Domain
import Foundation

/// Vadesiz hesap ekstreleri. Kart ekstrelerinden ayrı tutuluyor, çünkü yön
/// bilgisi başka yerden geliyor: kartta her satır harcamadır, hesapta yönü
/// tutarın işareti söyler. İkisi karışınca 50.000 TL'lik para girişi de çıkış
/// olarak yazılıyordu.
///
/// İkisinin de imzası sütun başlığı satırı: banka adı açıklama metninde de
/// geçebiliyor ("… Türkiye Garanti Bankasi A.S. …"), başlık satırı geçemez.

/// Halkbank hesap özeti:
/// `gg-aa-yyyy TUTAR BAKİYE AÇIKLAMA`
///
/// Açıklama uzunsa alt satıra taşıyor; taşan satır tarihle başlamadığı için
/// atlanıyor, tutar zaten ilk satırda okunmuş oluyor.
public struct HalkbankHesapOzetiParser: StatementParsing {
    public let formatIdentifier = "halkbank.hesapOzeti.v1"
    public let bankName = "Halkbank"
    public let signatures = ["ISLEM TARIHI ISLEM TUTARI BAKIYE ACIKLAMA"]

    public init() {}

    public func parse(_ text: String, calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated() {
            let line = TextNormalizer.collapseSpaces(
                String(rawLine).trimmingCharacters(in: .whitespaces))
            guard !line.isEmpty else { continue }

            var fields = line.split(separator: " ").map(String.init)
            guard fields.count >= 4,
                  let date = StatementDateParser.parse(fields[0], calendar: calendar)
            else { continue }
            fields.removeFirst()

            // Bazı satırlarda valör tarihi ve fazladan bir sayı var:
            // "05-05-2026 05-05-2026 500,00 -1.010,00 1.157,78 …". Baştaki tarih
            // ve sayılar toplanıp son ikisi tutar ve bakiye alınıyor; açıklamadan
            // hemen önceki iki sayı her iki düzende de o ikisi.
            while let first = fields.first,
                  StatementDateParser.parse(first, calendar: calendar) != nil {
                fields.removeFirst()
            }
            // Kuruş ayracı zorunlu: açıklama kart numarasıyla başlayabiliyor
            // ("0000000000000000 Kredi Kart Odeme") ve o da sayı gibi okunurdu.
            var numbers: [(amount: Money, isNegative: Bool)] = []
            while let first = fields.first, first.contains(","),
                  let parsed = AmountParser.parse(first) {
                numbers.append(parsed)
                fields.removeFirst()
            }

            guard numbers.count >= 2 else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: index + 1, text: line,
                    reason: "Tutar veya bakiye alanı okunamadı"))
                continue
            }
            let amount = numbers[numbers.count - 2]
            let balance = numbers[numbers.count - 1]
            guard amount.amount.minorUnits > 0 else { continue }

            let detail = fields.joined(separator: " ")
            guard !detail.isEmpty else { continue }

            result.rows.append(ParsedRow(
                date: date, detail: detail, amount: amount.amount,
                direction: amount.isNegative ? .expense : .income,
                runningBalance: balance.isNegative ? -balance.amount : balance.amount,
                lineNumber: index + 1))
        }
        return result
    }
}

/// Garanti BBVA hesap hareketleri:
/// `gg.aa.yyyy AÇIKLAMA ETİKET ±TUTAR TL ±BAKİYE TL`
///
/// Açıklama alt satıra taşabiliyor ve tutarlar o taşan satırda kalıyor:
/// ```
/// 02.08.2026 SERKAN D-Babama hediye parası yarısı-
/// FAST-1534679706 Para Transferi +700,00 TL 703,64 TL
/// ```
/// Bu yüzden tarihli satırda tutar yoksa satır bir sonrakiyle birleştiriliyor.
public struct GarantiHesapHareketleriParser: StatementParsing {
    public let formatIdentifier = "garanti.hesapHareketleri.v1"
    public let bankName = "Garanti BBVA"
    public let signatures = ["TARIH ACIKLAMA ETIKET TUTAR BAKIYE"]

    public init() {}

    public func parse(_ text: String, calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { TextNormalizer.collapseSpaces(String($0).trimmingCharacters(in: .whitespaces)) }

        var index = 0
        while index < lines.count {
            let lineNumber = index + 1
            var line = lines[index]
            index += 1
            guard !line.isEmpty,
                  let first = line.split(separator: " ").first,
                  let date = StatementDateParser.parse(String(first), calendar: calendar)
            else { continue }

            // Tutarlar satırın sonunda; yoksa açıklama taşmış demektir.
            if amounts(in: line) == nil, index < lines.count {
                line = TextNormalizer.collapseSpaces(line + " " + lines[index])
                index += 1
            }
            guard let parsed = amounts(in: line) else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: lineNumber, text: line,
                    reason: "Tutar ve bakiye alanları bulunamadı"))
                continue
            }
            guard parsed.amount.amount.minorUnits > 0 else { continue }

            result.rows.append(ParsedRow(
                date: date, detail: parsed.detail, amount: parsed.amount.amount,
                // Hesap ekstresinde yönü tutarın işareti söyler.
                direction: parsed.amount.isNegative ? .expense : .income,
                runningBalance: parsed.balance.isNegative
                    ? -parsed.balance.amount : parsed.balance.amount,
                lineNumber: lineNumber))
        }
        return result
    }

    /// Satır sonu `… ±TUTAR TL ±BAKİYE TL` düzenindedir; ondan öncesi açıklama.
    private func amounts(in line: String)
        -> (detail: String, amount: (amount: Money, isNegative: Bool),
            balance: (amount: Money, isNegative: Bool))? {
        var fields = line.split(separator: " ").map(String.init)
        guard fields.count >= 5, fields.last == "TL" else { return nil }
        fields.removeLast()
        guard let balance = AmountParser.parse(fields.removeLast()),
              fields.last == "TL" else { return nil }
        fields.removeLast()
        guard let amount = AmountParser.parse(fields.removeLast()) else { return nil }

        // İlk alan tarih, son alanlar tutar: aradaki her şey açıklama ve etiket.
        let detail = fields.dropFirst().joined(separator: " ")
        guard !detail.isEmpty else { return nil }
        return (detail, amount, balance)
    }
}
