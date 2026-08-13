import Foundation

/// İlk açılışta yazılan kategori listesi.
///
/// Tasarımın 12 renk yuvası gider kategorileri içindir. Ekranlarda geçen "Yeme-içme"
/// 13. gider kategorisi olarak eklendi ve yuvayı Bağış ile paylaşır — 12 yuva dolu,
/// paylaşım kaçınılmaz; en seyrek kullanılan yuva seçildi.
/// Gelir kategorileri ayrı, yuvaları yeniden kullanır. Transfer kategori değil, yöndür.
///
/// SF Symbols adları yer tutucudur: tasarım dosyası kategori ikonlarını "harf monogram
/// yer tutucu" diye işaretliyor ve gerçek eşleme henüz yok.
public enum DefaultCategories {
    public static func seed() -> [CategoryEntity] {
        var index = 0
        func next() -> Int { defer { index += 1 }; return index }

        let expenses: [(String, Int, String)] = [
            ("Market", 0, "cart"),
            ("Ulaşım", 1, "car"),
            ("Faturalar", 2, "doc.text"),
            ("Sağlık", 3, "cross.case"),
            ("Abonelik", 4, "repeat"),
            ("Ev", 5, "house"),
            ("Eğitim", 6, "book"),
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
