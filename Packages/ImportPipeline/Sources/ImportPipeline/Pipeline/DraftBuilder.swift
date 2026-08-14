import Core
import Domain
import Foundation

/// Ayrıştırılan satırları onay ekranı modeline çevirir: normalize eder,
/// kategoriler, mükerrer kontrolü yapar.
public struct DraftBuilder: Sendable {
    let categorizer: CategorizationEngine
    let accountID: UUID

    public init(categorizer: CategorizationEngine, accountID: UUID) {
        self.categorizer = categorizer
        self.accountID = accountID
    }

    public func build(
        from result: ParseResult,
        fileName: String,
        bankName: String,
        existingHashes: Set<String>,
        usedOCR: Bool = false,
        calendar: Calendar = .gregorianIstanbul
    ) -> ImportDraft {
        var rows: [ImportDraftRow] = []

        for parsed in result.rows {
            let hash = DuplicateHash.make(date: parsed.date, amount: parsed.amount,
                                          detail: parsed.detail, calendar: calendar)
            let suggestion = categorizer.suggest(detail: parsed.detail,
                                                 direction: parsed.direction)
            // İki güven çarpılmaz, en zayıf halka belirler.
            let confidence = min(parsed.confidence, suggestion.confidence)
            let isDuplicate = existingHashes.contains(hash)

            let kind: ImportDraftRow.Kind = if isDuplicate {
                .duplicate
            } else if usedOCR || confidence < CategorizationEngine.reviewThreshold {
                // Taranmış PDF'te tüm satırlar kontrol işaretiyle gelir.
                .needsReview
            } else {
                .automatic
            }

            rows.append(ImportDraftRow(
                date: parsed.date, detail: parsed.detail, amount: parsed.amount,
                direction: parsed.direction, categoryID: suggestion.categoryID,
                confidence: confidence, kind: kind,
                // Mükerrer varsayılan olarak eklenmez; kullanıcı yine de seçebilir.
                isSelected: !isDuplicate,
                lineNumber: parsed.lineNumber, duplicateHash: hash))
        }

        // Ayrıştırılamayan satırlar da listeye girer: sessizce kaybolmamalı.
        for unparsed in result.unparsed {
            rows.append(ImportDraftRow(
                date: Date(), detail: unparsed.text, amount: .zero,
                direction: .expense, categoryID: nil, confidence: 0,
                kind: .needsReview, isSelected: false,
                lineNumber: unparsed.lineNumber, duplicateHash: ""))
        }

        // Kontrol gerektirenler üstte (C3), sonra otomatik, en sonda mükerrer.
        rows.sort { lhs, rhs in
            func rank(_ kind: ImportDraftRow.Kind) -> Int {
                switch kind {
                case .needsReview: 0
                case .automatic: 1
                case .duplicate: 2
                }
            }
            if rank(lhs.kind) != rank(rhs.kind) { return rank(lhs.kind) < rank(rhs.kind) }
            return lhs.lineNumber < rhs.lineNumber
        }

        return ImportDraft(fileName: fileName, formatIdentifier: result.formatIdentifier,
                           bankName: bankName, rows: rows, usedOCR: usedOCR)
    }

    /// Onaylanan satırlar Domain varlığına çevrilir.
    public func transactions(from draft: ImportDraft,
                             importBatchID: UUID) -> [TransactionEntity] {
        draft.rows
            .filter { $0.isSelected && $0.amount.minorUnits > 0 }
            .map { row in
                TransactionEntity(
                    date: row.date, amount: row.amount, direction: row.direction,
                    detail: row.detail, categoryID: row.categoryID, accountID: accountID,
                    source: .statement, importBatchID: importBatchID,
                    statementLineNumber: row.lineNumber, duplicateHash: row.duplicateHash,
                    categoryConfidence: row.wasRecategorized ? nil : row.confidence,
                    needsReview: row.kind == .needsReview)
            }
    }
}
