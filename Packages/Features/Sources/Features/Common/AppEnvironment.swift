import Domain
import Foundation
import SwiftUI

/// Ekranların ihtiyaç duyduğu her şey tek yerden geçer. Repository gerçeklemesi
/// dışarıdan verilir: üretimde SwiftData, testte bellek içi.
@Observable
public final class AppEnvironment: @unchecked Sendable {
    public let transactions: any TransactionRepository
    public let accounts: any AccountRepository
    public let categories: any CategoryRepository
    public let budgets: any BudgetRepository
    public let categoryRules: any CategoryRuleRepository
    public let importBatches: any ImportBatchRepository
    public let parserProfiles: (any ParserProfileRepository)?
    /// Test ve önizlemede "bugün"ü sabitlemek için; üretimde Date().
    public let now: @Sendable () -> Date
    public let calendar: Calendar

    public var service: TransactionService {
        TransactionService(transactions: transactions, accounts: accounts,
                           categories: categories, categoryRules: categoryRules)
    }

    public init(
        transactions: any TransactionRepository,
        accounts: any AccountRepository,
        categories: any CategoryRepository,
        budgets: any BudgetRepository,
        categoryRules: any CategoryRuleRepository,
        importBatches: any ImportBatchRepository,
        parserProfiles: (any ParserProfileRepository)? = nil,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transactions = transactions
        self.accounts = accounts
        self.categories = categories
        self.budgets = budgets
        self.categoryRules = categoryRules
        self.importBatches = importBatches
        self.parserProfiles = parserProfiles
        self.calendar = calendar
        self.now = now
    }
}
