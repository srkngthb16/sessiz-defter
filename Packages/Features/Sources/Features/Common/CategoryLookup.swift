import DesignSystem
import Domain
import Foundation

/// Kategori kimliğinden ad, renk yuvası ve sembole ulaşmak listede satır başına
/// gerekiyor; her satırda repository'ye gitmemek için tek seferde yüklenip taşınır.
public struct CategoryLookup: Sendable {
    public private(set) var byID: [UUID: CategoryEntity]

    public init(_ categories: [CategoryEntity] = []) {
        byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    public func name(_ id: UUID?) -> String {
        guard let id, let category = byID[id] else { return "Kategorisiz" }
        return category.name
    }

    public func symbolName(_ id: UUID?) -> String {
        guard let id, let category = byID[id] else { return "questionmark" }
        return category.symbolName
    }

    public func colorIndex(_ id: UUID?) -> Int {
        guard let id, let category = byID[id] else { return 11 }
        return category.colorIndex
    }

    public var expenseCategories: [CategoryEntity] {
        byID.values.filter { $0.direction == .expense && !$0.isArchived }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    public var incomeCategories: [CategoryEntity] {
        byID.values.filter { $0.direction == .income && !$0.isArchived }
            .sorted { $0.sortIndex < $1.sortIndex }
    }
}

public struct AccountLookup: Sendable {
    public private(set) var byID: [UUID: AccountEntity]
    public let ordered: [AccountEntity]

    public init(_ accounts: [AccountEntity] = []) {
        byID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        ordered = accounts.sorted { $0.sortIndex < $1.sortIndex }
    }

    public func displayName(_ id: UUID?) -> String {
        guard let id, let account = byID[id] else { return "—" }
        return account.displayName
    }
}

extension TransactionDirection {
    /// DesignSystem Domain'i tanımıyor; köprü burada.
    public var style: TransactionDirectionStyle {
        switch self {
        case .income: .income
        case .expense: .expense
        case .transfer: .transfer
        }
    }
}

extension TransactionEntity {
    /// "Market · Ziraat ••3412"
    public func metaLine(categories: CategoryLookup, accounts: AccountLookup) -> String {
        [categories.name(categoryID), accounts.displayName(accountID)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    public func rowModel(categories: CategoryLookup, accounts: AccountLookup,
                         isCritical: Bool = false) -> TransactionRow.Model {
        TransactionRow.Model(
            detail: detail,
            meta: metaLine(categories: categories, accounts: accounts),
            amount: amount,
            direction: direction.style,
            categorySymbolName: categories.symbolName(categoryID),
            categoryColorIndex: categories.colorIndex(categoryID),
            isCritical: isCritical,
            needsReview: needsReview)
    }
}
