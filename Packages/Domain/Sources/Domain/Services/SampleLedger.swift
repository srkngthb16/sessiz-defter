import Core
import Foundation

/// "Örnek veriyle gez" — ilk açılışta boş ekranla kalmamak için yazılan sahte defter.
///
/// Üretim kodunda durur, `#if DEBUG` ile ayrılmaz: TestFlight test kullanıcısı da
/// görecek, yani Release'te derlenmesi gerekiyor. Ayırt edilebilirliği koşullu
/// derlemeyle değil kimlikle sağlanır — her kayıt tek bir sabit ImportBatch'e
/// bağlanır, temizleme yalnızca o kimliğe bakar ve kullanıcının kendi kaydına
/// dokunmaz.
public enum SampleLedger {
    /// Sabit kimlikler: "hangi kayıt örnek" sorusu ada ya da tarihe bakarak
    /// tahmin edilmez. Kullanıcı örnek işlemi düzenlerse bile bağ kopmaz.
    public static let batchID = UUID(uuidString: "5A3D1E00-0000-4000-A000-000000000001")!
    public static let accountID = UUID(uuidString: "5A3D1E00-0000-4000-A000-000000000002")!

    public static let accountName = "Örnek Banka"
    public static let fileName = "Örnek veri"
    public static let transactionCount = 20

    /// İki örnek bütçe: biri uyarı, biri aşım eşiğinde. Dashboard yalnızca dikkat
    /// isteyen bütçeleri gösterdiği için "yolunda" bir bütçe demoda görünmezdi.
    public static let warningBudgetID = UUID(uuidString: "5A3D1E00-0000-4000-A000-000000000003")!
    public static let exceededBudgetID = UUID(uuidString: "5A3D1E00-0000-4000-A000-000000000004")!

    public struct Ledger: Sendable {
        public let account: AccountEntity
        public let batch: ImportBatchEntity
        public let transactions: [TransactionEntity]
        public let budgets: [BudgetEntity]
    }

    /// Örnek işlemler kullanıcının kendi hesabına yazılmaz: ayrı bir örnek hesap
    /// açılır. Böylece temizleme sonrası gerçek hesabın bakiyesi hiç oynamamış olur.
    public static func make(
        now: Date,
        calendar: Calendar,
        categories: [CategoryEntity]
    ) -> Ledger {
        let categoryID = Dictionary(
            categories.map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })
        let today = calendar.startOfDay(for: now)

        let transactions = entries.enumerated().map { index, entry -> TransactionEntity in
            // Gün başına sabit bir saat ekleniyor: aynı güne düşen kayıtlar listede
            // rastgele değil, tabloda yazdığı sırada görünsün.
            let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: today) ?? today
            let date = calendar.date(byAdding: .minute, value: 540 + index, to: day) ?? day
            return TransactionEntity(
                date: date,
                amount: Money(minorUnits: entry.minorUnits),
                direction: entry.direction,
                detail: entry.detail,
                categoryID: categoryID[entry.categoryName],
                accountID: accountID,
                source: .statement,
                importBatchID: batchID,
                statementLineNumber: index + 1,
                categoryConfidence: entry.confidence,
                needsReview: entry.confidence.map { $0 < 0.6 } ?? false,
                createdAt: now
            )
        }

        let account = AccountEntity(
            id: accountID,
            name: accountName,
            kind: .checking,
            openingBalance: Money(minorUnits: 1_240_000),
            maskedNumber: "••4417",
            sortIndex: 900,
            createdAt: now
        )

        let dates = transactions.map(\.date)
        let batch = ImportBatchEntity(
            id: batchID,
            fileName: fileName,
            importedAt: now,
            periodStart: dates.min(),
            periodEnd: dates.max(),
            addedCount: transactions.count
        )

        return Ledger(account: account, batch: batch, transactions: transactions,
                      budgets: budgets(categoryID: categoryID, now: now, calendar: calendar))
    }

    /// Limitler bu ayın örnek harcamasına göre seçildi: Market %93 (limite yakın),
    /// Ulaşım %114 (aşıldı). Sabit tutar yazılsaydı ayın kaçıncı gününde açıldığına
    /// göre bazen ikisi de "yolunda" çıkıyordu.
    private static func budgets(
        categoryID: [String: UUID],
        now: Date,
        calendar: Calendar
    ) -> [BudgetEntity] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month],
                                                                     from: now)) ?? now
        var result: [BudgetEntity] = []
        if let market = categoryID["Market"] {
            result.append(BudgetEntity(id: warningBudgetID, categoryID: market,
                                       limit: Money(minorUnits: 120_000),
                                       startDate: monthStart))
        }
        if let transport = categoryID["Ulaşım"] {
            result.append(BudgetEntity(id: exceededBudgetID, categoryID: transport,
                                       limit: Money(minorUnits: 140_000),
                                       startDate: monthStart))
        }
        return result
    }

    private struct Entry {
        let daysAgo: Int
        let detail: String
        let minorUnits: Int
        let direction: TransactionDirection
        let categoryName: String
        /// nil = elle atanmış gibi davranır. 0,6 altındaki değerler "kontrol
        /// gerekiyor" rozetini doğurur; iki satır bilerek düşük bırakıldı ki
        /// test kullanıcısı o akışı da görsün.
        let confidence: Double?
    }

    /// Tutarlar 2026 Türkiye fiyat seviyesine göre seçildi; ekrandaki bakiye,
    /// bütçe oranı ve rapor dilimleri gerçekçi görünmezse örnek veri işe yaramaz.
    private static let entries: [Entry] = [
        Entry(daysAgo: 0, detail: "Migros Ataşehir", minorUnits: 48_725,
              direction: .expense, categoryName: "Market", confidence: 0.94),
        Entry(daysAgo: 1, detail: "Shell Kadıköy", minorUnits: 120_000,
              direction: .expense, categoryName: "Ulaşım", confidence: 0.91),
        Entry(daysAgo: 2, detail: "Netflix", minorUnits: 22_999,
              direction: .expense, categoryName: "Abonelik", confidence: 0.97),
        Entry(daysAgo: 3, detail: "Starbucks Bağdat Caddesi", minorUnits: 18_500,
              direction: .expense, categoryName: "Yeme-içme", confidence: 0.88),
        Entry(daysAgo: 4, detail: "İSKİ Su Faturası", minorUnits: 31_240,
              direction: .expense, categoryName: "Faturalar", confidence: 0.96),
        Entry(daysAgo: 5, detail: "Eczane Yaşam", minorUnits: 27_600,
              direction: .expense, categoryName: "Sağlık", confidence: 0.83),
        Entry(daysAgo: 7, detail: "İstanbulkart Dolum", minorUnits: 40_000,
              direction: .expense, categoryName: "Ulaşım", confidence: 0.90),
        Entry(daysAgo: 8, detail: "Trendyol Sipariş", minorUnits: 89_990,
              direction: .expense, categoryName: "Alışveriş", confidence: 0.79),
        Entry(daysAgo: 10, detail: "Spotify", minorUnits: 8_499,
              direction: .expense, categoryName: "Abonelik", confidence: 0.97),
        Entry(daysAgo: 11, detail: "BİM Göztepe", minorUnits: 63_430,
              direction: .expense, categoryName: "Market", confidence: 0.93),
        Entry(daysAgo: 13, detail: "Kira Ödemesi", minorUnits: 1_800_000,
              direction: .expense, categoryName: "Ev", confidence: nil),
        Entry(daysAgo: 14, detail: "Elektrik - Enerjisa", minorUnits: 47_810,
              direction: .expense, categoryName: "Faturalar", confidence: 0.95),
        Entry(daysAgo: 15, detail: "Maaş Ödemesi", minorUnits: 4_850_000,
              direction: .income, categoryName: "Maaş", confidence: nil),
        Entry(daysAgo: 16, detail: "Kuaför Ada", minorUnits: 55_000,
              direction: .expense, categoryName: "Kişisel bakım", confidence: 0.72),
        Entry(daysAgo: 18, detail: "Sinema Bileti", minorUnits: 34_000,
              direction: .expense, categoryName: "Eğlence", confidence: 0.81),
        Entry(daysAgo: 20, detail: "Kitapyurdu", minorUnits: 42_750,
              direction: .expense, categoryName: "Eğitim", confidence: 0.55),
        Entry(daysAgo: 21, detail: "Serbest Proje Ödemesi", minorUnits: 1_250_000,
              direction: .income, categoryName: "Serbest çalışma", confidence: nil),
        Entry(daysAgo: 22, detail: "Yemeksepeti", minorUnits: 31_500,
              direction: .expense, categoryName: "Yeme-içme", confidence: 0.86),
        Entry(daysAgo: 24, detail: "AKBATI OTOPARK", minorUnits: 12_000,
              direction: .expense, categoryName: "Ulaşım", confidence: 0.42),
        Entry(daysAgo: 27, detail: "LC WAIKIKI", minorUnits: 74_990,
              direction: .expense, categoryName: "Alışveriş", confidence: 0.77)
    ]
}
