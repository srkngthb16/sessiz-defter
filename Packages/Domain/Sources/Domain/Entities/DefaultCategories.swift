import Foundation

/// İlk açılışta yazılan kategori listesi.
///
/// Tasarımın 12 renk yuvası gider kategorileri içindir. Ekranlarda geçen "Yeme-içme"
/// 13. gider kategorisi olarak eklendi ve yuvayı Bağış ile paylaşır — 12 yuva dolu,
/// paylaşım kaçınılmaz; en seyrek kullanılan yuva seçildi.
/// Gelir kategorileri ayrı, yuvaları yeniden kullanır. Transfer kategori değil, yöndür.
///
/// SF Symbols eşlemesinin tek kaynağı burasıdır; seçim gerekçeleri
/// `docs/CATEGORY-ICONS.md`. Ayarlardaki simge seçici de bu listeden türer —
/// üç yerde ayrı yazılınca biri güncellenip diğerleri geride kalıyordu.
public enum DefaultCategories {
    /// Kullanıcı yeni kategori açtığında başlangıç simgesi: nötr, hiçbir harcama
    /// alanını çağrıştırmayan tek simge.
    public static let fallbackSymbol = "tag"

    /// Varsayılanların simgeleri + kullanıcının kendi kategorisi için genel simgeler.
    /// Sıra korunur, tekrar elenir.
    public static func symbolChoices() -> [String] {
        var seen = Set<String>()
        return (seed().map(\.symbolName) + extraSymbols).filter { seen.insert($0).inserted }
    }

    /// Varsayılan listede karşılığı olmayan yaygın harcama alanları. Hepsi tek
    /// çizgi (dolgusuz) varyant.
    private static let extraSymbols = [
        fallbackSymbol, "creditcard", "gift", "pawprint", "airplane",
        "wrench.and.screwdriver", "dumbbell", "gamecontroller", "cup.and.saucer",
        "building.columns"
    ]

    public static func seed() -> [CategoryEntity] {
        var index = 0
        func next() -> Int { defer { index += 1 }; return index }

        let expenses: [(String, Int, String)] = [
            ("Market", 0, "cart"),
            // Ulaşım kalemlerinin çoğu toplu taşıma; "car" yalnız sürücüyü anlatıyordu.
            ("Ulaşım", 1, "bus"),
            ("Faturalar", 2, "doc.text"),
            ("Sağlık", 3, "cross.case"),
            // "repeat" bir medya glifi; yinelenen ödeme için dönen ok okunaklı.
            ("Abonelik", 4, "arrow.triangle.2.circlepath"),
            ("Ev", 5, "house"),
            // "book" uygulamanın kendi marka işareti (book.closed) ile karışıyordu.
            ("Eğitim", 6, "graduationcap"),
            ("Eğlence", 7, "theatermasks"),
            ("Alışveriş", 8, "bag"),
            ("Kişisel bakım", 9, "scissors"),
            ("Bağış", 10, "heart"),
            ("Yeme-içme", 10, "fork.knife"),
            ("Diğer", 11, "ellipsis.circle")
        ]
        let incomes: [(String, Int, String)] = [
            ("Maaş", 3, "banknote"),
            ("Serbest çalışma", 6, "laptopcomputer"),
            ("Diğer gelir", 11, "plus.circle")
        ]

        return expenses.map {
            CategoryEntity(name: $0.0, colorIndex: $0.1, symbolName: $0.2,
                           direction: .expense, sortIndex: next())
        } + incomes.map {
            CategoryEntity(name: $0.0, colorIndex: $0.1, symbolName: $0.2,
                           direction: .income, sortIndex: next())
        }
    }
}
