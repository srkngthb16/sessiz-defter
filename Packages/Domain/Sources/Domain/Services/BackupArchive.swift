import Core
import Foundation

/// F1 — "Yedek dışa aktar · şifreli .sdb dosyası · Dosyalar'a".
/// Arşiv düz JSON'dur; şifreleme dosya yazılmadan önce Core/PasswordCrypto ile yapılır.
public struct BackupArchive: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version: Int
    public var createdAt: Date
    public var accounts: [AccountEntity]
    public var categories: [CategoryEntity]
    public var transactions: [TransactionEntity]
    public var budgets: [BudgetEntity]
    public var importBatches: [ImportBatchEntity]
    public var parserProfiles: [ParserProfileEntity]
    public var categoryRules: [CategoryRuleEntity]

    public init(
        version: Int = BackupArchive.currentVersion,
        createdAt: Date = Date(),
        accounts: [AccountEntity] = [],
        categories: [CategoryEntity] = [],
        transactions: [TransactionEntity] = [],
        budgets: [BudgetEntity] = [],
        importBatches: [ImportBatchEntity] = [],
        parserProfiles: [ParserProfileEntity] = [],
        categoryRules: [CategoryRuleEntity] = []
    ) {
        self.version = version
        self.createdAt = createdAt
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.budgets = budgets
        self.importBatches = importBatches
        self.parserProfiles = parserProfiles
        self.categoryRules = categoryRules
    }

    public var summary: String {
        "\(transactions.count) işlem · \(accounts.count) hesap · \(budgets.count) bütçe"
    }

    /// Tarih stratejisi belirtilmez (Date'in kendi kodlaması kullanılır): ISO8601
    /// alt saniyeyi atıyor ve yedekten dönen kayıt kaynağıyla birebir eşleşmiyordu.
    /// Dosya zaten şifreli, insan tarafından okunmuyor; kesinlik okunabilirlikten önce.
    public static func encode(_ archive: BackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(archive)
    }

    public static func decode(_ data: Data) throws -> BackupArchive {
        try JSONDecoder().decode(BackupArchive.self, from: data)
    }
}

public enum BackupError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case emptyArchive
}

/// Yedek alma ve geri yükleme. Geri yükleme yıkıcıdır: mevcut defter silinir.
public protocol BackupServing: Sendable {
    func makeArchive() async throws -> BackupArchive
    func restore(_ archive: BackupArchive) async throws
}

public struct BackupFile: Sendable {
    public static let fileExtension = "sdb"

    /// "SessizDefter-2026-08-14.sdb"
    public static func suggestedName(for date: Date,
                                     calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "SessizDefter-%04d-%02d-%02d.%@",
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, fileExtension)
    }
}
