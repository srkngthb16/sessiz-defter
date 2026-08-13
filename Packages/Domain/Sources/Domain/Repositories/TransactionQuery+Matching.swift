import Core
import Foundation

extension TransactionQuery {
    /// Filtre semantiği tek yerde: in-memory ve SwiftData gerçeklemeleri aynı kuralı kullanır,
    /// böylece testte geçen davranış üretimde de aynı kalır.
    public func matches(_ transaction: TransactionEntity) -> Bool {
        if let dateRange, !dateRange.contains(transaction.date) { return false }
        if !categoryIDs.isEmpty {
            guard let categoryID = transaction.categoryID,
                  categoryIDs.contains(categoryID) else { return false }
        }
        if !accountIDs.isEmpty, !accountIDs.contains(transaction.accountID) { return false }
        if !directions.isEmpty, !directions.contains(transaction.direction) { return false }
        if let minimumAmount, transaction.amount < minimumAmount { return false }
        if let maximumAmount, transaction.amount > maximumAmount { return false }
        if onlyNeedsReview, !transaction.needsReview { return false }
        if let searchText, !searchText.isEmpty, !Self.textMatches(searchText, transaction) {
            return false
        }
        return true
    }

    /// Arama açıklamada, notta ve tutarın yazılı halinde çalışır ("İşlem, hesap veya tutar ara").
    /// Karşılaştırma tr_TR büyük harfe çevrilerek yapılır: "İ" ve "ı" bozulmasın.
    static func textMatches(_ needle: String, _ transaction: TransactionEntity) -> Bool {
        let query = needle.trUpper
        if transaction.detail.trUpper.contains(query) { return true }
        if let note = transaction.note, note.trUpper.contains(query) { return true }
        if transaction.tags.contains(where: { $0.trUpper.contains(query) }) { return true }
        if Fmt.amount(transaction.amount).contains(query) { return true }
        return false
    }

    public func apply(to transactions: [TransactionEntity]) -> [TransactionEntity] {
        let filtered = transactions
            .filter(matches)
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.createdAt > rhs.createdAt
            }
        guard let limit else { return filtered }
        return Array(filtered.prefix(limit))
    }
}
