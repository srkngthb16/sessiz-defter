import Core
import Foundation

public enum AccountKind: String, Codable, Sendable, CaseIterable {
    case checking
    case creditCard
    case cash
}

public struct AccountEntity: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: AccountKind
    public var currencyCode: String
    public var openingBalance: Money
    /// "••3412" — ekranlarda hesap adının yanında görünen maske. IBAN saklanmaz.
    public var maskedNumber: String?
    public var isArchived: Bool
    public var sortIndex: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        currencyCode: String = "TRY",
        openingBalance: Money = .zero,
        maskedNumber: String? = nil,
        isArchived: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.currencyCode = currencyCode
        self.openingBalance = openingBalance
        self.maskedNumber = maskedNumber
        self.isArchived = isArchived
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    /// "Ziraat ••3412"
    public var displayName: String {
        guard let maskedNumber else { return name }
        return "\(name) \(maskedNumber)"
    }
}
