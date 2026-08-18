import Core
import Domain
import Foundation

/// Kredi kartı ekstrelerinde satır bilgisi PDF'in metin katmanına sütun sütun
/// değil karışık geliyor: bir satırda birden çok işlem, tutarlar sonraki
/// satırlarda. Buradaki iki ayrıştırıcı bu yüzden satır satır değil, "işlem
/// başlıklarıyla tutarların sayısı tutuyor mu" kuralıyla çalışıyor.
///
/// Ortak kural: sayı tutmuyorsa satır **atlanıyor**. Yanlış tutar okumak,
/// okumamaktan kötü — kullanıcı eksik satırı fark eder, yanlış bakiyeyi etmez.

/// Halkbank Paraf kredi kartı ekstresi:
/// `gg/aa/yyyy AÇIKLAMA TUTAR KALAN[/TAKSİT]`
///
/// Ödeme satırlarında tutar bir alt satıra düşüyor ve başında `+` oluyor:
/// ```
/// 11/07/2026 Hesaptan Ödeme - Teşekkür Ederiz
/// + 500.00 0.00
/// ```
public struct HalkbankParafParser: StatementParsing {
    public let formatIdentifier = "halkbank.paraf.v1"
    public let bankName = "Halkbank"
    public let signatures = ["HALK BANKASI", "TUTAR(TL)"]

    public init() {}

    public func parse(_ text: String, calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        var pending: (date: Date, detail: String, lineNumber: Int)?

        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated() {
            let line = TextNormalizer.collapseSpaces(
                String(rawLine).trimmingCharacters(in: .whitespaces))
            guard !line.isEmpty else { continue }

            let fields = line.split(separator: " ").map(String.init)
            if let first = fields.first,
               let date = StatementDateParser.parse(first, calendar: calendar) {
                let rest = Array(fields.dropFirst())
                if let row = row(date: date, fields: rest, lineNumber: index + 1) {
                    result.rows.append(row)
                    pending = nil
                } else {
                    // Tutarsız tarih satırı: tutarı bir alt satırda arayacağız.
                    pending = (date, rest.joined(separator: " "), index + 1)
                }
                continue
            }

            // Devam satırı yalnız **bir sonraki** satır olabilir. Önceden tutar
            // bulunana kadar aşağı bakılıyordu ve sayfa altbilgisi işlem sanılıyordu.
            guard let waiting = pending else { continue }
            pending = nil
            if let row = row(date: waiting.date, fields: fields,
                             detailOverride: waiting.detail, lineNumber: waiting.lineNumber) {
                result.rows.append(row)
            } else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: waiting.lineNumber, text: waiting.detail,
                    reason: "Tutar alanı okunamadı"))
            }
        }
        return result
    }

    /// Kuruşu olan sayı. Kart ekstresinde tutarlar daima iki ondalık taşıyor;
    /// bu şart olmadan ekstrenin dipnotundaki posta kodu ("34760 Ümraniye")
    /// tutar sanılıp deftere 34.760,00 TL gider olarak yazılıyordu.
    private func isMoney(_ token: String) -> Bool {
        var text = token
        if text.hasPrefix("+") || text.hasPrefix("-") { text.removeFirst() }
        if text.hasSuffix("+") || text.hasSuffix("-") { text.removeLast() }
        guard let separator = text.lastIndex(of: "."), text.distance(
            from: text.index(after: separator), to: text.endIndex) == 2 else { return false }
        return text.allSatisfy { $0.isNumber || $0 == "." || $0 == "," }
    }

    /// Son alan "kalan borç / taksit" sütunu; ondan önceki alan işlem tutarı.
    private func row(date: Date, fields: [String], detailOverride: String? = nil,
                     lineNumber: Int) -> ParsedRow? {
        var fields = fields
        if let last = fields.last, last.contains("/") || isMoney(last) {
            fields.removeLast()
        }
        guard let amountToken = fields.last, isMoney(amountToken),
              let parsed = AmountParser.parse(amountToken),
              parsed.amount.minorUnits > 0 else { return nil }
        fields.removeLast()

        let detail = (detailOverride ?? fields.joined(separator: " "))
            .replacingOccurrences(of: "+", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !detail.isEmpty else { return nil }

        // Kart ekstresinde satırlar harcamadır; `+` taşıyan satır karta yapılan
        // ödemedir, yani borcu azaltır.
        let isPayment = amountToken.contains("+") || fields.contains("+")
        return ParsedRow(date: date, detail: detail, amount: parsed.amount,
                         direction: isPayment ? .income : .expense,
                         runningBalance: nil, lineNumber: lineNumber)
    }
}

/// Garanti BBVA Bonus kredi kartı ekstresi. Tarih uzun yazılıyor
/// ("16 Haziran 2026") ve PDF metin katmanı sütunları iç içe geçiriyor:
/// ```
/// 29 Haziran 2026 TOPLU TASIMA UCRETI 29 Haziran 2026 TOPLU TASIMA UCRETI 42,00
/// 42,00
/// ```
/// Yani bir satırda k işlem başlığı, ardından k tutar. Eşleşme yalnız sayı
/// tuttuğunda kuruluyor; tutmadığında satır atlanıp rapora yazılıyor.
public struct GarantiBonusParser: StatementParsing {
    public let formatIdentifier = "garanti.bonus.v1"
    public let bankName = "Garanti BBVA"
    public let signatures = ["GARANTI", "BONUS"]

    public init() {}

    private struct Entry {
        let date: Date
        let detail: String
    }

    private struct Amount {
        let value: Money
        let isCredit: Bool
    }

    public func parse(_ text: String, calendar: Calendar = .gregorianIstanbul) -> ParseResult {
        var result = ParseResult(formatIdentifier: formatIdentifier)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { TextNormalizer.collapseSpaces(String($0).trimmingCharacters(in: .whitespaces)) }

        var index = 0
        while index < lines.count {
            let lineNumber = index + 1
            let line = lines[index]
            index += 1
            guard !line.isEmpty else { continue }

            let parsed = split(line: line, calendar: calendar)
            // Açıklaması olmayan başlık işlem değil: "Hesap Kesim Tarihi 14 Temmuz
            // 2026" gibi satırlar da tarih taşıyor.
            let entries = parsed.entries.filter { !$0.detail.isEmpty }
            guard !entries.isEmpty, entries.count == parsed.entries.count else { continue }

            // Alt satırlardaki tutarların **hepsi** toplanıyor, sayı yeter yetmez
            // durulmuyor: erken durmak, devir bakiyesini ilk işlemin tutarı diye
            // okumaya yol açıyordu.
            var amounts = parsed.amounts
            var lookahead = index
            while lookahead < lines.count, let value = amountOnly(lines[lookahead]) {
                amounts.append(value)
                lookahead += 1
            }
            guard !amounts.isEmpty else { continue }

            // Sütun düzeni: "… Kalan Borç / Taksit · Bonus (TL) · Tutar (TL)".
            // Bonus sütunu doluysa her işleme iki sayı düşüyor ve ikincisi tutardır.
            let matched: [Amount]
            if amounts.count == entries.count {
                matched = amounts
            } else if amounts.count == entries.count * 2 {
                matched = stride(from: 1, to: amounts.count, by: 2).map { amounts[$0] }
            } else {
                result.unparsed.append(UnparsedRow(
                    lineNumber: lineNumber, text: line,
                    reason: "\(entries.count) işlem başlığına \(amounts.count) tutar düşüyor"))
                continue
            }
            index = lookahead

            for (entry, amount) in zip(entries, matched) {
                guard amount.value.minorUnits > 0 else { continue }
                result.rows.append(ParsedRow(
                    date: entry.date, detail: entry.detail, amount: amount.value,
                    // `+` karta yapılan ödeme, `-` iade ya da bonus kullanımı:
                    // ikisi de borcu azaltır.
                    direction: amount.isCredit ? .income : .expense,
                    runningBalance: nil, lineNumber: lineNumber))
            }
        }
        return result
    }

    /// Satırı "tarih + açıklama" gruplarına ve sondaki tutarlara ayırır.
    private func split(line: String, calendar: Calendar)
        -> (entries: [Entry], amounts: [Amount]) {
        let tokens = line.split(separator: " ").map(String.init)
        var entries: [Entry] = []
        var amounts: [Amount] = []
        var openDate: Date?
        var detail: [String] = []

        var position = 0
        while position < tokens.count {
            // Uzun tarih üç sözcük: "16 Haziran 2026".
            if position + 3 <= tokens.count {
                let candidate = tokens[position..<(position + 3)].joined(separator: " ")
                if let date = StatementDateParser.parse(candidate, calendar: calendar) {
                    if let open = openDate {
                        entries.append(Entry(date: open, detail: detail.joined(separator: " ")))
                    }
                    openDate = date
                    detail = []
                    position += 3
                    continue
                }
            }
            detail.append(tokens[position])
            position += 1
        }

        guard let open = openDate else { return ([], []) }
        // Açıklamanın sonundaki tutarlar işlem tutarıdır, metne karışmamalı.
        while let last = detail.last, looksLikeAmount(last),
              let parsed = AmountParser.parse(last) {
            amounts.insert(Amount(value: parsed.amount,
                                  isCredit: last.hasSuffix("+") || parsed.isNegative), at: 0)
            detail.removeLast()
        }
        entries.append(Entry(date: open, detail: detail.joined(separator: " ")))
        return (entries, amounts)
    }

    private func amountOnly(_ line: String) -> Amount? {
        guard looksLikeAmount(line), let parsed = AmountParser.parse(line) else { return nil }
        return Amount(value: parsed.amount, isCredit: line.hasSuffix("+") || parsed.isNegative)
    }

    /// "1.015,21" evet, "338,40x3=1.015,21" hayır: taksit açıklaması tutar
    /// sanılmamalı. Kuruş ayracı zorunlu, çünkü ekstredeki "2026" gibi sayılar da
    /// aksi halde tutar sayılırdı.
    private func looksLikeAmount(_ token: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "0123456789.,+-")
        return !token.isEmpty
            && token.unicodeScalars.allSatisfy(allowed.contains)
            && token.contains(",")
    }
}
