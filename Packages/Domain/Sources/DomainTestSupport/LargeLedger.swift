import Core
import Domain
import Foundation

/// Performans ölçümü için büyük defter üreteci.
///
/// `SampleLedger` 20 kayıtlık, kullanıcıya görünen demo verisi; bu üretici yalnız
/// testlerde kullanılır. Rastgelelik tohumlu: ölçüm koşudan koşuya aynı veriyle
/// yapılmazsa sayılar karşılaştırılamaz.
public enum LargeLedger {
    public struct Ledger: Sendable {
        public let accounts: [AccountEntity]
        public let categories: [CategoryEntity]
        public let transactions: [TransactionEntity]
    }

    public static func make(
        transactionCount: Int = 10_000,
        now: Date,
        calendar: Calendar = .current
    ) -> Ledger {
        var random = SeededGenerator(seed: 0x5D10_2026)
        let categories = DefaultCategories.seed()
        let expenseCategories = categories.filter { $0.direction == .expense }
        let incomeCategories = categories.filter { $0.direction == .income }

        let accounts = [
            AccountEntity(name: "Vadesiz", kind: .checking,
                          openingBalance: Money(minorUnits: 5_000_000),
                          maskedNumber: "••1001", sortIndex: 0),
            AccountEntity(name: "Kredi Kartı", kind: .creditCard,
                          maskedNumber: "••2002", sortIndex: 1),
            AccountEntity(name: "Nakit", kind: .cash, sortIndex: 2)
        ]

        let merchants = ["Migros", "BİM", "A101", "Shell", "Opet", "Trendyol",
                         "Hepsiburada", "Getir", "Yemeksepeti", "Netflix",
                         "Spotify", "İSKİ", "Enerjisa", "Eczane", "Kuaför",
                         "Sinema", "Kitapyurdu", "LC Waikiki", "Starbucks",
                         "İstanbulkart"]
        let districts = ["Ataşehir", "Kadıköy", "Beşiktaş", "Üsküdar", "Bakırköy"]

        let transactions = (0..<transactionCount).map { index -> TransactionEntity in
            // Kayıtlar iki yıla yayılıyor: tek aya sıkışırsa dönem sorguları
            // gerçekte olmayacak kadar kolay iş yapıyor.
            let minutesBack = random.next(upTo: 60 * 24 * 730)
            let date = calendar.date(byAdding: .minute, value: -minutesBack, to: now) ?? now
            let isIncome = index % 40 == 0
            let category = isIncome
                ? incomeCategories[random.next(upTo: incomeCategories.count)]
                : expenseCategories[random.next(upTo: expenseCategories.count)]
            let detail = isIncome
                ? "Ödeme \(index)"
                : "\(merchants[random.next(upTo: merchants.count)]) "
                    + "\(districts[random.next(upTo: districts.count)]) \(index)"
            let minorUnits = isIncome
                ? 2_000_000 + random.next(upTo: 3_000_000)
                : 1_000 + random.next(upTo: 200_000)

            return TransactionEntity(
                date: date,
                amount: Money(minorUnits: minorUnits),
                direction: isIncome ? .income : .expense,
                detail: detail,
                categoryID: category.id,
                accountID: accounts[random.next(upTo: accounts.count)].id,
                source: .statement,
                statementLineNumber: index + 1,
                categoryConfidence: 0.9,
                needsReview: index % 97 == 0,
                createdAt: date)
        }

        return Ledger(accounts: accounts, categories: categories,
                      transactions: transactions)
    }
}

/// SplitMix64 — kısa, bağımlılıksız, tohumlanabilir. `SystemRandomNumberGenerator`
/// tohum almadığı için ölçümü tekrarlanabilir yapmıyordu.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(upTo bound: Int) -> Int {
        bound <= 0 ? 0 : Int(next() % UInt64(bound))
    }
}
