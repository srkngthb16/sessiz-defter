import Core
import Foundation

public enum BudgetPeriod: String, Codable, Sendable, CaseIterable {
    case monthly
}

public struct BudgetEntity: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var categoryID: UUID
    public var period: BudgetPeriod
    public var limit: Money
    /// %80 eşiğinde yerel bildirim. Ağ kullanılmaz.
    public var warnsAtEightyPercent: Bool
    /// Artan tutar sonraki döneme eklenir.
    public var rollsOver: Bool
    public var startDate: Date
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        categoryID: UUID,
        period: BudgetPeriod = .monthly,
        limit: Money,
        warnsAtEightyPercent: Bool = true,
        rollsOver: Bool = false,
        startDate: Date,
        isArchived: Bool = false
    ) {
        self.id = id
        self.categoryID = categoryID
        self.period = period
        self.limit = limit.magnitude
        self.warnsAtEightyPercent = warnsAtEightyPercent
        self.rollsOver = rollsOver
        self.startDate = startDate
        self.isArchived = isArchived
    }
}
