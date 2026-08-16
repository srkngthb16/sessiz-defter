import Domain
import Testing
import UIKit

/// Eşlemeyi Domain değil bu hedef sınıyor: `UIImage(systemName:)` yalnızca UIKit'in
/// olduğu yerde çalışır ve yanlış yazılmış bir simge adı ekranda sessizce boş kutu
/// çiziyor — derleme hatası vermiyor.
@Suite("Kategori simgeleri")
struct CategoryIconTests {
    @Test("Varsayılan kategorilerin simgeleri sistemde çözülüyor")
    func varsayilanlar() {
        for category in DefaultCategories.seed() {
            #expect(UIImage(systemName: category.symbolName) != nil,
                    "\(category.name) → \(category.symbolName) çözülmedi")
        }
    }

    @Test("Simge seçicideki her ad çözülüyor")
    func secici() {
        for symbol in DefaultCategories.symbolChoices() {
            #expect(UIImage(systemName: symbol) != nil, "\(symbol) çözülmedi")
        }
        #expect(UIImage(systemName: DefaultCategories.fallbackSymbol) != nil)
    }

    @Test("Seçici varsayılanların tamamını içerir ve tekrar barındırmaz")
    func kapsam() {
        let choices = DefaultCategories.symbolChoices()
        let defaults = DefaultCategories.seed().map(\.symbolName)
        #expect(Set(defaults).isSubset(of: Set(choices)))
        #expect(Set(choices).count == choices.count)
        #expect(choices.contains(DefaultCategories.fallbackSymbol))
    }

    @Test("13 gider kategorisinin simgeleri birbirinden ayrı")
    func giderSimgeleriAyri() {
        let expense = DefaultCategories.seed()
            .filter { $0.direction == .expense }
            .map(\.symbolName)
        #expect(Set(expense).count == expense.count)
    }
}
