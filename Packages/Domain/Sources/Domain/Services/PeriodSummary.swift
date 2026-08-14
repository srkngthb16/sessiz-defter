import Core
import Foundation

/// Dashboard ve raporların ortak özet birimi.
public struct PeriodSummary: Hashable, Sendable {
    public let income: Money
    public let expense: Money

    public init(income: Money = .zero, expense: Money = .zero) {
        self.income = income
        self.expense = expense
    }

    /// Transferler dışarıda: dönem içi net etki gelir eksi giderdir.
    public var net: Money { income - expense }

    public static func make(from transactions: [TransactionEntity]) -> PeriodSummary {
        var income = Money.zero
        var expense = Money.zero
        for transaction in transactions {
            switch transaction.direction {
            case .income: income = income + transaction.amount
            case .expense: expense = expense + transaction.amount
            case .transfer: continue
            }
        }
        return PeriodSummary(income: income, expense: expense)
    }
}

public struct CategoryBreakdownItem: Hashable, Sendable, Identifiable {
    public let categoryID: UUID?
    public let amount: Money
    /// 0...1 — dönemin toplam giderindeki payı.
    public let share: Double

    public var id: UUID { categoryID ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")! }

    public init(categoryID: UUID?, amount: Money, share: Double) {
        self.categoryID = categoryID
        self.amount = amount
        self.share = share
    }
}

public enum CategoryBreakdown {
    /// Gider dağılımı, tutara göre azalan. 8'den fazla dilim varsa kalanlar "Diğer"de
    /// toplanır — grafik paleti sekiz renk taşır.
    public static func make(
        from transactions: [TransactionEntity],
        limit: Int = 8
    ) -> [CategoryBreakdownItem] {
        var totals: [UUID?: Int] = [:]
        for transaction in transactions where transaction.direction == .expense {
            totals[transaction.categoryID, default: 0] += transaction.amount.minorUnits
        }
        let grandTotal = totals.values.reduce(0, +)
        guard grandTotal > 0 else { return [] }

        let sorted = totals.sorted { $0.value > $1.value }
        let head = sorted.prefix(limit)
        let tail = sorted.dropFirst(limit)

        var items = head.map { entry in
            CategoryBreakdownItem(
                categoryID: entry.key,
                amount: Money(minorUnits: entry.value),
                share: Double(entry.value) / Double(grandTotal))
        }
        if !tail.isEmpty {
            let rest = tail.reduce(0) { $0 + $1.value }
            items.append(CategoryBreakdownItem(
                categoryID: nil,
                amount: Money(minorUnits: rest),
                share: Double(rest) / Double(grandTotal)))
        }
        return items
    }
}
