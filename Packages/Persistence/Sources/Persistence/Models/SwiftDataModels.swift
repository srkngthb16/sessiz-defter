import Foundation
import SwiftData

// Kalıcılık modelleri Domain varlıklarından ayrı: Domain saf Swift kalmak zorunda.
// Enum'lar String raw değerle saklanır — şema göçünde ham veri okunabilir kalsın.

@Model
final class SDAccount {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var currencyCode: String
    var openingBalanceMinorUnits: Int
    var maskedNumber: String?
    var isArchived: Bool
    var sortIndex: Int
    var createdAt: Date

    init(id: UUID, name: String, kindRaw: String, currencyCode: String,
         openingBalanceMinorUnits: Int, maskedNumber: String?, isArchived: Bool,
         sortIndex: Int, createdAt: Date) {
        self.id = id
        self.name = name
        self.kindRaw = kindRaw
        self.currencyCode = currencyCode
        self.openingBalanceMinorUnits = openingBalanceMinorUnits
        self.maskedNumber = maskedNumber
        self.isArchived = isArchived
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

@Model
final class SDCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorIndex: Int
    var symbolName: String
    var directionRaw: String
    var isArchived: Bool
    var sortIndex: Int

    init(id: UUID, name: String, colorIndex: Int, symbolName: String,
         directionRaw: String, isArchived: Bool, sortIndex: Int) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.symbolName = symbolName
        self.directionRaw = directionRaw
        self.isArchived = isArchived
        self.sortIndex = sortIndex
    }
}

@Model
final class SDTransaction {
    // #Index iOS 18+ olduğu için kullanılmıyor; hedef iOS 17.
    // date ve duplicateHash sorguları FetchDescriptor predicate'i ile çalışıyor.
    @Attribute(.unique) var id: UUID
    var date: Date
    var amountMinorUnits: Int
    var currencyCode: String
    var directionRaw: String
    var detail: String
    var categoryID: UUID?
    var accountID: UUID
    var counterpartAccountID: UUID?
    var note: String?
    var tags: [String]
    var sourceRaw: String
    var importBatchID: UUID?
    var statementLineNumber: Int?
    var duplicateHash: String
    var categoryConfidence: Double?
    var needsReview: Bool
    var createdAt: Date

    init(id: UUID, date: Date, amountMinorUnits: Int, currencyCode: String,
         directionRaw: String, detail: String, categoryID: UUID?, accountID: UUID,
         counterpartAccountID: UUID?, note: String?, tags: [String], sourceRaw: String,
         importBatchID: UUID?, statementLineNumber: Int?, duplicateHash: String,
         categoryConfidence: Double?, needsReview: Bool, createdAt: Date) {
        self.id = id
        self.date = date
        self.amountMinorUnits = amountMinorUnits
        self.currencyCode = currencyCode
        self.directionRaw = directionRaw
        self.detail = detail
        self.categoryID = categoryID
        self.accountID = accountID
        self.counterpartAccountID = counterpartAccountID
        self.note = note
        self.tags = tags
        self.sourceRaw = sourceRaw
        self.importBatchID = importBatchID
        self.statementLineNumber = statementLineNumber
        self.duplicateHash = duplicateHash
        self.categoryConfidence = categoryConfidence
        self.needsReview = needsReview
        self.createdAt = createdAt
    }
}

@Model
final class SDBudget {
    @Attribute(.unique) var id: UUID
    var categoryID: UUID
    var periodRaw: String
    var limitMinorUnits: Int
    var currencyCode: String
    var warnsAtEightyPercent: Bool
    var rollsOver: Bool
    var startDate: Date
    var isArchived: Bool

    init(id: UUID, categoryID: UUID, periodRaw: String, limitMinorUnits: Int,
         currencyCode: String, warnsAtEightyPercent: Bool, rollsOver: Bool,
         startDate: Date, isArchived: Bool) {
        self.id = id
        self.categoryID = categoryID
        self.periodRaw = periodRaw
        self.limitMinorUnits = limitMinorUnits
        self.currencyCode = currencyCode
        self.warnsAtEightyPercent = warnsAtEightyPercent
        self.rollsOver = rollsOver
        self.startDate = startDate
        self.isArchived = isArchived
    }
}

@Model
final class SDImportBatch {
    @Attribute(.unique) var id: UUID
    var fileName: String
    var importedAt: Date
    var periodStart: Date?
    var periodEnd: Date?
    var addedCount: Int
    var skippedDuplicateCount: Int
    var manuallyRecategorizedCount: Int
    var bankFormatIdentifier: String?
    var sourceFileRetained: Bool
    var usedOCR: Bool

    init(id: UUID, fileName: String, importedAt: Date, periodStart: Date?, periodEnd: Date?,
         addedCount: Int, skippedDuplicateCount: Int, manuallyRecategorizedCount: Int,
         bankFormatIdentifier: String?, sourceFileRetained: Bool, usedOCR: Bool) {
        self.id = id
        self.fileName = fileName
        self.importedAt = importedAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.addedCount = addedCount
        self.skippedDuplicateCount = skippedDuplicateCount
        self.manuallyRecategorizedCount = manuallyRecategorizedCount
        self.bankFormatIdentifier = bankFormatIdentifier
        self.sourceFileRetained = sourceFileRetained
        self.usedOCR = usedOCR
    }
}

@Model
final class SDParserProfile {
    @Attribute(.unique) var id: UUID
    var bankName: String
    var formatIdentifier: String
    var signatures: [String]
    var columnMappingRaw: [String]
    var isUserDefined: Bool
    var createdAt: Date
    var lastUsedAt: Date?

    init(id: UUID, bankName: String, formatIdentifier: String, signatures: [String],
         columnMappingRaw: [String], isUserDefined: Bool, createdAt: Date, lastUsedAt: Date?) {
        self.id = id
        self.bankName = bankName
        self.formatIdentifier = formatIdentifier
        self.signatures = signatures
        self.columnMappingRaw = columnMappingRaw
        self.isUserDefined = isUserDefined
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

@Model
final class SDCategoryRule {
    @Attribute(.unique) var id: UUID
    var keyword: String
    var categoryID: UUID
    var directionRaw: String?
    var isUserDefined: Bool
    var createdAt: Date

    init(id: UUID, keyword: String, categoryID: UUID, directionRaw: String?,
         isUserDefined: Bool, createdAt: Date) {
        self.id = id
        self.keyword = keyword
        self.categoryID = categoryID
        self.directionRaw = directionRaw
        self.isUserDefined = isUserDefined
        self.createdAt = createdAt
    }
}

enum SchemaV1 {
    static let models: [any PersistentModel.Type] = [
        SDAccount.self, SDCategory.self, SDTransaction.self,
        SDBudget.self, SDImportBatch.self, SDParserProfile.self, SDCategoryRule.self
    ]
}
