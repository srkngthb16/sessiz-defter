import Core
import Domain
import Foundation

/// Ayrıştırma sonrası kullanıcıya gösterilen döküm. "46 satır bulundu" yetmiyor:
/// bir ekstre yanlış okunduğunda nerede kaybedildiğini görebilmek gerekiyor.
public struct ParseReport: Hashable, Sendable {
    public let totalLines: Int
    public let candidateLines: Int
    public let parsedRows: Int
    public let skippedRows: [SkipReason: Int]
    public let formatIdentifier: String
    public let bankName: String
    /// Ekstrenin kendi yazdığı toplamlar; okunanla karşılaştırmak için.
    public let declaredTotals: [StatementTotals.Declared]

    public enum SkipReason: String, Hashable, Sendable, CaseIterable {
        case noDate = "Tarih okunamadı"
        case noAmount = "Tutar okunamadı"
        case emptyDetail = "Açıklama boş"
        case zeroAmount = "Tutar sıfır"
        case notATransaction = "İşlem satırı değil"
    }

    public init(totalLines: Int, candidateLines: Int, parsedRows: Int,
                skippedRows: [SkipReason: Int], formatIdentifier: String,
                bankName: String, declaredTotals: [StatementTotals.Declared] = []) {
        self.totalLines = totalLines
        self.candidateLines = candidateLines
        self.parsedRows = parsedRows
        self.skippedRows = skippedRows
        self.formatIdentifier = formatIdentifier
        self.bankName = bankName
        self.declaredTotals = declaredTotals
    }

    public var skippedTotal: Int { skippedRows.values.reduce(0, +) }

    /// Aday satırların çoğu okunamadıysa eşleme büyük olasılıkla yanlış.
    public var looksWrong: Bool {
        candidateLines > 0 && Double(parsedRows) / Double(candidateLines) < 0.5
    }

    public var summaryLine: String {
        "\(totalLines) satır tarandı · \(parsedRows) işlem okundu · \(skippedTotal) satır atlandı"
    }
}

/// Ekstre metnini paylaşılabilir hâle getirir: tutarlar ve harf dizileri maskelenir,
/// satır düzeni ve ayraçlar korunur. Amaç, biçimi göstermek ama içeriği göstermemek.
public enum StatementAnonymizer {
    public static func anonymize(_ text: String, maxLines: Int = 40) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(maxLines)
            .map { maskLine(String($0)) }
            .joined(separator: "\n")
    }

    static func maskLine(_ line: String) -> String {
        var result = ""
        var runOfLetters = 0

        func flushLetters() {
            guard runOfLetters > 0 else { return }
            // İlk harf kalır, kalanı X: kelime uzunluğu biçim için anlamlı,
            // içeriği değil.
            result += String(repeating: "X", count: runOfLetters)
            runOfLetters = 0
        }

        for character in line {
            if character.isLetter {
                runOfLetters += 1
            } else if character.isNumber {
                flushLetters()
                result.append("9")
            } else {
                flushLetters()
                result.append(character)
            }
        }
        flushLetters()
        return result
    }
}

extension ParseReport {
    /// Raporu ayrıştırma sonucundan ve ham metinden türetir.
    public static func make(from result: ParseResult, text: String,
                            bankName: String,
                            calendar: Calendar = .gregorianIstanbul) -> ParseReport {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        // Aday satır: ilk alanı tarih olarak okunabilen satır. Başlık, altbilgi ve
        // toplam satırları bu ölçüte takılmaz.
        let candidates = nonEmpty.filter { line in
            guard let first = TextNormalizer.collapseSpaces(String(line))
                .split(separator: " ").first else { return false }
            return StatementDateParser.parse(String(first), calendar: calendar) != nil
        }

        var skipped: [SkipReason: Int] = [:]
        for row in result.unparsed {
            let reason: SkipReason = if row.reason.contains("Tutar") {
                .noAmount
            } else if row.reason.contains("Açıklama") {
                .emptyDetail
            } else if row.reason.contains("Tarih") {
                .noDate
            } else {
                .notATransaction
            }
            skipped[reason, default: 0] += 1
        }
        let unaccounted = max(0, candidates.count - result.rows.count - result.unparsed.count)
        if unaccounted > 0 { skipped[.zeroAmount, default: 0] += unaccounted }

        return ParseReport(
            totalLines: nonEmpty.count,
            candidateLines: candidates.count,
            parsedRows: result.rows.count,
            skippedRows: skipped,
            formatIdentifier: result.formatIdentifier,
            bankName: bankName,
            declaredTotals: StatementTotals.declared(in: text))
    }
}

/// Kaydedilen eşlemenin sonraki ekstrede tanınabilmesi için metinden imza türetir.
/// İmza yoksa profil hiçbir dosyayla eşleşmez ve eşleme boşa gider.
public enum StatementSignature {
    public static func derive(from text: String, count: Int = 2) -> [String] {
        let headLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(8)
            .map { TextNormalizer.fold(TextNormalizer.collapseSpaces(String($0))) }
            .filter { $0.count >= 6 }

        // Tarih ya da tutar taşıyan satır imza olamaz: her ekstrede değişir.
        let stable = headLines.filter { line in
            !line.contains(where: \.isNumber)
        }
        let source = stable.isEmpty ? headLines : stable
        return Array(source.prefix(count))
    }
}
