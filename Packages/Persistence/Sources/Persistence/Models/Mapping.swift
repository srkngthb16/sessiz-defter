import Core
import Domain
import Foundation

// Kalıcılık modeli ↔ Domain varlığı çevirisi. Tek yön kuralı: Domain bu dosyayı görmez.

extension SDAccount {
    var entity: AccountEntity {
        AccountEntity(
            id: id,
            name: name,
            kind: AccountKind(rawValue: kindRaw) ?? .checking,
            currencyCode: currencyCode,
            openingBalance: Money(minorUnits: openingBalanceMinorUnits, currencyCode: currencyCode),
            maskedNumber: maskedNumber,
            isArchived: isArchived,
            sortIndex: sortIndex,
            createdAt: createdAt)
    }

    static func make(_ entity: AccountEntity) -> SDAccount {
        SDAccount(
            id: entity.id, name: entity.name, kindRaw: entity.kind.rawValue,
            currencyCode: entity.currencyCode,
            openingBalanceMinorUnits: entity.openingBalance.minorUnits,
            maskedNumber: entity.maskedNumber, isArchived: entity.isArchived,
            sortIndex: entity.sortIndex, createdAt: entity.createdAt)
    }

    func apply(_ entity: AccountEntity) {
        name = entity.name
        kindRaw = entity.kind.rawValue
        currencyCode = entity.currencyCode
        openingBalanceMinorUnits = entity.openingBalance.minorUnits
        maskedNumber = entity.maskedNumber
        isArchived = entity.isArchived
        sortIndex = entity.sortIndex
    }
}

extension SDCategory {
    var entity: CategoryEntity {
        CategoryEntity(
            id: id, name: name, colorIndex: colorIndex, symbolName: symbolName,
            direction: TransactionDirection(rawValue: directionRaw) ?? .expense,
            isArchived: isArchived, sortIndex: sortIndex)
    }

    static func make(_ entity: CategoryEntity) -> SDCategory {
        SDCategory(
            id: entity.id, name: entity.name, colorIndex: entity.colorIndex,
            symbolName: entity.symbolName, directionRaw: entity.direction.rawValue,
            isArchived: entity.isArchived, sortIndex: entity.sortIndex)
    }

    func apply(_ entity: CategoryEntity) {
        name = entity.name
        colorIndex = entity.colorIndex
        symbolName = entity.symbolName
        directionRaw = entity.direction.rawValue
        isArchived = entity.isArchived
        sortIndex = entity.sortIndex
    }
}

extension SDTransaction {
    var entity: TransactionEntity {
        TransactionEntity(
            id: id, date: date,
            amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode),
            direction: TransactionDirection(rawValue: directionRaw) ?? .expense,
            detail: detail, categoryID: categoryID, accountID: accountID,
            counterpartAccountID: counterpartAccountID, note: note, tags: tags,
            source: TransactionSource(rawValue: sourceRaw) ?? .manual,
            importBatchID: importBatchID, statementLineNumber: statementLineNumber,
            duplicateHash: duplicateHash, categoryConfidence: categoryConfidence,
            needsReview: needsReview, createdAt: createdAt)
    }

    static func make(_ entity: TransactionEntity) -> SDTransaction {
        SDTransaction(
            id: entity.id, date: entity.date,
            amountMinorUnits: entity.amount.minorUnits,
            currencyCode: entity.amount.currencyCode,
            directionRaw: entity.direction.rawValue, detail: entity.detail,
            categoryID: entity.categoryID, accountID: entity.accountID,
            counterpartAccountID: entity.counterpartAccountID, note: entity.note,
            tags: entity.tags, sourceRaw: entity.source.rawValue,
            importBatchID: entity.importBatchID,
            statementLineNumber: entity.statementLineNumber,
            duplicateHash: entity.duplicateHash,
            categoryConfidence: entity.categoryConfidence,
            needsReview: entity.needsReview, createdAt: entity.createdAt)
    }

    func apply(_ entity: TransactionEntity) {
        date = entity.date
        amountMinorUnits = entity.amount.minorUnits
        currencyCode = entity.amount.currencyCode
        directionRaw = entity.direction.rawValue
        detail = entity.detail
        categoryID = entity.categoryID
        accountID = entity.accountID
        counterpartAccountID = entity.counterpartAccountID
        note = entity.note
        tags = entity.tags
        sourceRaw = entity.source.rawValue
        importBatchID = entity.importBatchID
        statementLineNumber = entity.statementLineNumber
        duplicateHash = entity.duplicateHash
        categoryConfidence = entity.categoryConfidence
        needsReview = entity.needsReview
    }
}

extension SDBudget {
    var entity: BudgetEntity {
        BudgetEntity(
            id: id, categoryID: categoryID,
            period: BudgetPeriod(rawValue: periodRaw) ?? .monthly,
            limit: Money(minorUnits: limitMinorUnits, currencyCode: currencyCode),
            warnsAtEightyPercent: warnsAtEightyPercent, rollsOver: rollsOver,
            startDate: startDate, isArchived: isArchived)
    }

    static func make(_ entity: BudgetEntity) -> SDBudget {
        SDBudget(
            id: entity.id, categoryID: entity.categoryID, periodRaw: entity.period.rawValue,
            limitMinorUnits: entity.limit.minorUnits, currencyCode: entity.limit.currencyCode,
            warnsAtEightyPercent: entity.warnsAtEightyPercent, rollsOver: entity.rollsOver,
            startDate: entity.startDate, isArchived: entity.isArchived)
    }

    func apply(_ entity: BudgetEntity) {
        categoryID = entity.categoryID
        periodRaw = entity.period.rawValue
        limitMinorUnits = entity.limit.minorUnits
        currencyCode = entity.limit.currencyCode
        warnsAtEightyPercent = entity.warnsAtEightyPercent
        rollsOver = entity.rollsOver
        startDate = entity.startDate
        isArchived = entity.isArchived
    }
}

extension SDImportBatch {
    var entity: ImportBatchEntity {
        ImportBatchEntity(
            id: id, fileName: fileName, importedAt: importedAt,
            periodStart: periodStart, periodEnd: periodEnd, addedCount: addedCount,
            skippedDuplicateCount: skippedDuplicateCount,
            manuallyRecategorizedCount: manuallyRecategorizedCount,
            bankFormatIdentifier: bankFormatIdentifier,
            sourceFileRetained: sourceFileRetained, usedOCR: usedOCR)
    }

    static func make(_ entity: ImportBatchEntity) -> SDImportBatch {
        SDImportBatch(
            id: entity.id, fileName: entity.fileName, importedAt: entity.importedAt,
            periodStart: entity.periodStart, periodEnd: entity.periodEnd,
            addedCount: entity.addedCount,
            skippedDuplicateCount: entity.skippedDuplicateCount,
            manuallyRecategorizedCount: entity.manuallyRecategorizedCount,
            bankFormatIdentifier: entity.bankFormatIdentifier,
            sourceFileRetained: entity.sourceFileRetained, usedOCR: entity.usedOCR)
    }

    func apply(_ entity: ImportBatchEntity) {
        fileName = entity.fileName
        importedAt = entity.importedAt
        periodStart = entity.periodStart
        periodEnd = entity.periodEnd
        addedCount = entity.addedCount
        skippedDuplicateCount = entity.skippedDuplicateCount
        manuallyRecategorizedCount = entity.manuallyRecategorizedCount
        bankFormatIdentifier = entity.bankFormatIdentifier
        sourceFileRetained = entity.sourceFileRetained
        usedOCR = entity.usedOCR
    }
}

extension SDParserProfile {
    var entity: ParserProfileEntity {
        ParserProfileEntity(
            id: id, bankName: bankName, formatIdentifier: formatIdentifier,
            signatures: signatures,
            columnMapping: columnMappingRaw.map { ColumnRole(rawValue: $0) ?? .ignored },
            isUserDefined: isUserDefined, createdAt: createdAt, lastUsedAt: lastUsedAt)
    }

    static func make(_ entity: ParserProfileEntity) -> SDParserProfile {
        SDParserProfile(
            id: entity.id, bankName: entity.bankName,
            formatIdentifier: entity.formatIdentifier, signatures: entity.signatures,
            columnMappingRaw: entity.columnMapping.map(\.rawValue),
            isUserDefined: entity.isUserDefined, createdAt: entity.createdAt,
            lastUsedAt: entity.lastUsedAt)
    }

    func apply(_ entity: ParserProfileEntity) {
        bankName = entity.bankName
        formatIdentifier = entity.formatIdentifier
        signatures = entity.signatures
        columnMappingRaw = entity.columnMapping.map(\.rawValue)
        isUserDefined = entity.isUserDefined
        lastUsedAt = entity.lastUsedAt
    }
}

extension SDCategoryRule {
    var entity: CategoryRuleEntity {
        CategoryRuleEntity(
            id: id, keyword: keyword, categoryID: categoryID,
            direction: directionRaw.flatMap(TransactionDirection.init(rawValue:)),
            isUserDefined: isUserDefined, createdAt: createdAt)
    }

    static func make(_ entity: CategoryRuleEntity) -> SDCategoryRule {
        SDCategoryRule(
            id: entity.id, keyword: entity.keyword, categoryID: entity.categoryID,
            directionRaw: entity.direction?.rawValue, isUserDefined: entity.isUserDefined,
            createdAt: entity.createdAt)
    }

    func apply(_ entity: CategoryRuleEntity) {
        keyword = entity.keyword
        categoryID = entity.categoryID
        directionRaw = entity.direction?.rawValue
        isUserDefined = entity.isUserDefined
    }
}
