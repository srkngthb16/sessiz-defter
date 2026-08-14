import Core
import Foundation

/// Bütçe durumu. Eşikler tasarımdan: %80 uyarı, %100 aşım.
public struct BudgetStatus: Identifiable, Hashable, Sendable {
    public enum State: Sendable, Hashable {
        case onTrack    // %80 altı
        case warning    // %80–%100
        case exceeded   // %100 üstü

        public var label: String {
            switch self {
            case .onTrack: "Yolunda"
            case .warning: "Limite yakın"
            case .exceeded: "Aşıldı"
            }
        }
    }

    public let budget: BudgetEntity
    public let spent: Money
    /// Devreden bakiye açıksa önceki dönemden artan tutar limite eklenir.
    public let effectiveLimit: Money
    public let daysRemaining: Int

    public var id: UUID { budget.id }

    public init(budget: BudgetEntity, spent: Money, effectiveLimit: Money,
                daysRemaining: Int) {
        self.budget = budget
        self.spent = spent
        self.effectiveLimit = effectiveLimit
        self.daysRemaining = daysRemaining
    }

    public var ratio: Double {
        guard effectiveLimit.minorUnits > 0 else { return 0 }
        return Double(spent.minorUnits) / Double(effectiveLimit.minorUnits)
    }

    public var state: State {
        if ratio > 1 { return .exceeded }
        if ratio >= BudgetEngine.warningThreshold { return .warning }
        return .onTrack
    }

    /// Aşımda negatif olur; ekranda "516,20 ₺ aşıldı" olarak okunur.
    public var remaining: Money { effectiveLimit - spent }

    public var overspend: Money? {
        remaining.isNegative ? remaining.magnitude : nil
    }

    /// "günlük 57,60 ₺ harcanabilir" — kalan tutar kalan güne bölünür.
    /// Dönem bittiyse ya da limit aşıldıysa günlük pay yoktur.
    public var dailyAllowance: Money? {
        guard daysRemaining > 0, remaining.minorUnits > 0 else { return nil }
        return Money(minorUnits: remaining.minorUnits / daysRemaining)
    }
}

public struct BudgetEngine: Sendable {
    public static let warningThreshold = 0.8

    let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Bir bütçenin dönem içi durumu. Yalnızca gider sayılır: gelir ve transfer
    /// bütçeyi tüketmez.
    public func status(
        for budget: BudgetEntity,
        transactions: [TransactionEntity],
        period: DateInterval,
        now: Date,
        carriedOver: Money = .zero
    ) -> BudgetStatus {
        let spent = transactions
            .filter { $0.direction == .expense
                && $0.categoryID == budget.categoryID
                && period.contains($0.date) }
            .reduce(Money.zero) { $0 + $1.amount }

        let effectiveLimit = budget.rollsOver ? budget.limit + carriedOver : budget.limit
        return BudgetStatus(
            budget: budget,
            spent: spent,
            effectiveLimit: effectiveLimit,
            daysRemaining: Period.remainingDays(in: period, from: now, calendar: calendar))
    }

    public func statuses(
        budgets: [BudgetEntity],
        transactions: [TransactionEntity],
        period: DateInterval,
        now: Date
    ) -> [BudgetStatus] {
        budgets
            .map { status(for: $0, transactions: transactions, period: period, now: now) }
            // Önce sorunlular: aşım, sonra uyarı, sonra yolunda.
            .sorted { lhs, rhs in
                func rank(_ state: BudgetStatus.State) -> Int {
                    switch state {
                    case .exceeded: 0
                    case .warning: 1
                    case .onTrack: 2
                    }
                }
                if rank(lhs.state) != rank(rhs.state) { return rank(lhs.state) < rank(rhs.state) }
                return lhs.ratio > rhs.ratio
            }
    }

    /// E1 üst kartı: tüm bütçelerin toplam limiti ve kalanı.
    public struct Overview: Hashable, Sendable {
        public let totalLimit: Money
        public let totalSpent: Money
        public let daysRemaining: Int

        public var remaining: Money { totalLimit - totalSpent }

        public var dailyAllowance: Money? {
            guard daysRemaining > 0, remaining.minorUnits > 0 else { return nil }
            return Money(minorUnits: remaining.minorUnits / daysRemaining)
        }
    }

    public func overview(_ statuses: [BudgetStatus], daysRemaining: Int) -> Overview {
        Overview(
            totalLimit: statuses.reduce(Money.zero) { $0 + $1.effectiveLimit },
            totalSpent: statuses.reduce(Money.zero) { $0 + $1.spent },
            daysRemaining: daysRemaining)
    }

    /// E2 — "Son 3 ayın Eğlence ortalaması 3.240 ₺."
    public func averageSpending(
        categoryID: UUID,
        transactions: [TransactionEntity],
        endingBefore date: Date,
        monthCount: Int = 3
    ) -> Money? {
        var totals: [Int] = []
        for offset in 1...monthCount {
            guard let anchor = calendar.date(byAdding: .month, value: -offset, to: date)
            else { continue }
            let period = Period.month(containing: anchor, calendar: calendar)
            let sum = transactions
                .filter { $0.direction == .expense
                    && $0.categoryID == categoryID
                    && period.contains($0.date) }
                .reduce(0) { $0 + $1.amount.minorUnits }
            totals.append(sum)
        }
        guard !totals.isEmpty, totals.contains(where: { $0 > 0 }) else { return nil }
        return Money(minorUnits: totals.reduce(0, +) / totals.count)
    }
}
