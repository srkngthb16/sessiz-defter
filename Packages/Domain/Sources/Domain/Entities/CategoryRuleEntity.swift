import Foundation

/// C4 — "PAPARA içeren satırlar → Transfer". Kullanıcının onay ekranında yaptığı
/// düzeltme kural olarak kaydedilebilir ve sonraki içe aktarmalarda uygulanır.
public struct CategoryRuleEntity: Identifiable, Hashable, Sendable {
    public let id: UUID
    /// Açıklamada aranan anahtar. Karşılaştırma ASCII'ye katlanmış büyük harfle yapılır.
    public var keyword: String
    public var categoryID: UUID
    public var direction: TransactionDirection?
    public var isUserDefined: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), keyword: String, categoryID: UUID,
                direction: TransactionDirection? = nil,
                isUserDefined: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.keyword = keyword
        self.categoryID = categoryID
        self.direction = direction
        self.isUserDefined = isUserDefined
        self.createdAt = createdAt
    }
}

public protocol CategoryRuleRepository: Sendable {
    func all() async throws -> [CategoryRuleEntity]
    func save(_ rule: CategoryRuleEntity) async throws
    func delete(id: UUID) async throws
}
