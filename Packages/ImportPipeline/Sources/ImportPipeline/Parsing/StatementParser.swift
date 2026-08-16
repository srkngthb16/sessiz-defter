import Core
import Domain
import Foundation

public protocol StatementParsing: Sendable {
    var formatIdentifier: String { get }
    var bankName: String { get }
    /// Başlık/altbilgi imzaları — BankFormatDetector bunlarla eşleştirir.
    var signatures: [String] { get }
    func parse(_ text: String, calendar: Calendar) -> ParseResult
}

extension StatementParsing {
    /// İmza eşleşmesi büyük/küçük harf ve Türkçe karakter farkına takılmamalı:
    /// ekstre metni çoğu zaman ASCII gelir ("ZIRAAT"), imza Türkçe yazılmış olabilir.
    public func matches(_ text: String) -> Bool {
        let haystack = TextNormalizer.fold(text)
        return signatures.allSatisfy { haystack.contains(TextNormalizer.fold($0)) }
    }
}

public enum TextNormalizer {
    static let folding: [Character: Character] = [
        "İ": "I", "I": "I", "ı": "I", "i": "I",
        "Ş": "S", "ş": "S", "Ğ": "G", "ğ": "G",
        "Ç": "C", "ç": "C", "Ö": "O", "ö": "O", "Ü": "U", "ü": "U"
    ]

    public static func fold(_ text: String) -> String {
        String(text.map { folding[$0] ?? $0 }).uppercased(with: Locale(identifier: "en_US"))
    }

    /// Ardışık boşlukları teke indirir; sütunlar boşlukla hizalandığı için ham
    /// satırda çok sayıda boşluk bulunur.
    public static func collapseSpaces(_ text: String) -> String {
        text.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }
}

/// Ziraat vadesiz hesap özeti: `gg/aa/yy AÇIKLAMA TUTAR± BAKİYE`
public struct ZiraatVadesizParser: StatementParsing {
    public let formatIdentifier = "ziraat.vadesiz.v1"
    public let bankName = "Ziraat Bankası"
    public let signatures = ["ZIRAAT BANKASI", "HESAP OZETI"]

    public init() {}

    public func parse(_ text: String, calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated() {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields = TextNormalizer.collapseSpaces(line).split(separator: " ")
            guard fields.count >= 3,
                  let date = StatementDateParser.parse(String(fields[0]), calendar: calendar)
            else { continue }

            // Son iki alan tutar ve yürüyen bakiye; arada kalan her şey açıklama.
            guard fields.count >= 4,
                  let parsedAmount = AmountParser.parse(String(fields[fields.count - 2])),
                  let balance = AmountParser.parse(String(fields[fields.count - 1]))
            else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: index + 1, text: line,
                    reason: "Tutar veya bakiye alanı okunamadı"))
                continue
            }

            let detail = fields[1..<(fields.count - 2)].joined(separator: " ")
            guard !detail.isEmpty else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: index + 1, text: line, reason: "Açıklama boş"))
                continue
            }
            // Sıfır tutarlı devir satırı işlem değildir.
            guard parsedAmount.amount.minorUnits > 0 else { continue }

            result.rows.append(ParsedRow(
                date: date,
                detail: detail,
                amount: parsedAmount.amount,
                direction: parsedAmount.isNegative ? .expense : .income,
                runningBalance: balance.isNegative
                    ? -balance.amount : balance.amount,
                lineNumber: index + 1))
        }
        return result
    }
}

/// Garanti kredi kartı ekstresi: `gg.aa.yyyy AÇIKLAMA TUTAR TL`
/// Kart ekstresinde satırlar harcamadır; eksi işaretli olanlar iadedir.
public struct GarantiKrediKartiParser: StatementParsing {
    public let formatIdentifier = "garanti.krediKarti.v1"
    public let bankName = "Garanti BBVA"
    public let signatures = ["GARANTI", "KREDI KARTI"]

    public init() {}

    public func parse(_ text: String, calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated() {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            var fields = TextNormalizer.collapseSpaces(line).split(separator: " ")
            guard fields.count >= 3,
                  let date = StatementDateParser.parse(String(fields[0]), calendar: calendar)
            else { continue }

            if fields.last == "TL" { fields.removeLast() }
            guard let parsedAmount = AmountParser.parse(String(fields[fields.count - 1])) else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: index + 1, text: line, reason: "Tutar alanı okunamadı"))
                continue
            }
            let detail = fields[1..<(fields.count - 1)].joined(separator: " ")
            guard !detail.isEmpty else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: index + 1, text: line, reason: "Açıklama boş"))
                continue
            }
            guard parsedAmount.amount.minorUnits > 0 else { continue }

            result.rows.append(ParsedRow(
                date: date,
                detail: detail,
                amount: parsedAmount.amount,
                // Eksi işaret iadedir; işaretsiz satır harcamadır.
                direction: parsedAmount.isNegative ? .income : .expense,
                lineNumber: index + 1))
        }
        return result
    }
}

/// C7 — tanınmayan format. Kullanıcı sütunları bir kez eşler, eşleme saklanır.
public struct GenericColumnParser: StatementParsing {
    public let formatIdentifier: String
    public let bankName: String
    public var signatures: [String] { signatureList }
    let signatureList: [String]
    /// Ayırıcı belirtilmezse boşluk sütunları kullanılır.
    public let separator: Character?
    public let columns: [ColumnRole]

    public init(formatIdentifier: String, bankName: String,
                separator: Character? = nil, columns: [ColumnRole],
                signatures: [String] = []) {
        self.formatIdentifier = formatIdentifier
        self.bankName = bankName
        self.separator = separator
        self.columns = columns
        self.signatureList = signatures
    }

    /// Kaydedilmiş kullanıcı eşlemesinden parser üretir. İmzası olmayan profil
    /// hiçbir metinle eşleşmez; kaydederken imza türetilmesi şart.
    public init?(profile: ParserProfileEntity) {
        guard !profile.columnMapping.isEmpty, !profile.signatures.isEmpty else { return nil }
        self.init(formatIdentifier: profile.formatIdentifier,
                  bankName: profile.bankName,
                  separator: profile.separator.flatMap(\.first),
                  columns: profile.columnMapping,
                  signatures: profile.signatures)
    }

    public func parse(_ text: String, calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated() {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let fields: [String]
            if let separator {
                fields = line.split(separator: separator).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
            } else {
                fields = TextNormalizer.collapseSpaces(line).split(separator: " ").map(String.init)
            }
            guard fields.count >= columns.count else { continue }

            var date: Date?
            var detailParts: [String] = []
            var amount: (amount: Money, isNegative: Bool)?
            var balance: Money?

            for (position, role) in columns.enumerated() {
                let field = fields[position]
                switch role {
                case .date: date = StatementDateParser.parse(field, calendar: calendar)
                case .detail: detailParts.append(field)
                case .amount: amount = AmountParser.parse(field)
                case .balance:
                    if let parsed = AmountParser.parse(field) {
                        balance = parsed.isNegative ? -parsed.amount : parsed.amount
                    }
                case .ignored: continue
                }
            }

            guard let date, let amount, amount.amount.minorUnits > 0 else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: index + 1, text: line,
                    reason: "Tarih veya tutar sütunu okunamadı"))
                continue
            }
            result.rows.append(ParsedRow(
                date: date,
                detail: detailParts.joined(separator: " "),
                amount: amount.amount,
                direction: amount.isNegative ? .expense : .income,
                runningBalance: balance,
                lineNumber: index + 1,
                // Kullanıcı eşlemesiyle okunan satırlar tam güvenle gelmez.
                confidence: 0.6))
        }
        return result
    }
}

public struct BankFormatDetector: Sendable {
    public let parsers: [any StatementParsing]

    public init(parsers: [any StatementParsing] = [ZiraatVadesizParser(),
                                                   GarantiKrediKartiParser()]) {
        self.parsers = parsers
    }

    /// Kullanıcının kaydettiği eşlemeler yerleşik parser'lardan ÖNCE denenir:
    /// kullanıcı bir bankanın biçimini elle düzelttiyse o düzeltme kazanmalı.
    public init(parsers: [any StatementParsing] = [ZiraatVadesizParser(),
                                                   GarantiKrediKartiParser()],
                savedProfiles: [ParserProfileEntity]) {
        self.parsers = savedProfiles.compactMap(GenericColumnParser.init(profile:)) + parsers
    }

    public func detect(in text: String) -> (any StatementParsing)? {
        parsers.first { $0.matches(text) }
    }
}
