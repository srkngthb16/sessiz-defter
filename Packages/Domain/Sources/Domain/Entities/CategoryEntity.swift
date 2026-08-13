import Foundation

public struct CategoryEntity: Identifiable, Hashable, Sendable {
    public static let colorSlotCount = 12

    public let id: UUID
    public var name: String
    /// Color.category.all dizisindeki indeks (0..<12). Renk hex'i Domain'de tutulmaz.
    public var colorIndex: Int
    public var symbolName: String
    public var direction: TransactionDirection
    /// Silme yerine arşivleme: geçmiş işlemlerin kategorisi boşa düşmesin.
    public var isArchived: Bool
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        colorIndex: Int,
        symbolName: String,
        direction: TransactionDirection = .expense,
        isArchived: Bool = false,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.colorIndex = max(0, min(colorIndex, Self.colorSlotCount - 1))
        self.symbolName = symbolName
        self.direction = direction
        self.isArchived = isArchived
        self.sortIndex = sortIndex
    }
}
