import Domain
import Testing

@Suite("Varsayılan kategoriler")
struct DefaultCategoriesTests {
    @Test("13 gider + 3 gelir kategorisi")
    func sayilar() {
        let seed = DefaultCategories.seed()
        #expect(seed.filter { $0.direction == .expense }.count == 13)
        #expect(seed.filter { $0.direction == .income }.count == 3)
        #expect(seed.contains { $0.direction == .transfer } == false)
    }

    @Test("Tasarımdaki 12 ad korunur ve renk yuvası sırasıyla eşleşir")
    func tasarimAdlari() {
        let seed = DefaultCategories.seed()
        let expected = ["Market", "Ulaşım", "Faturalar", "Sağlık", "Abonelik", "Ev",
                        "Eğitim", "Eğlence", "Alışveriş", "Kişisel bakım", "Bağış"]
        for (slot, name) in expected.enumerated() {
            let category = try! #require(seed.first { $0.name == name })
            #expect(category.colorIndex == slot, "\(name) yuvası \(category.colorIndex)")
        }
        #expect(seed.first { $0.name == "Diğer" }?.colorIndex == 11)
    }

    @Test("Her renk yuvası geçerli aralıkta, sıralama benzersiz")
    func gecerlilik() {
        let seed = DefaultCategories.seed()
        #expect(seed.allSatisfy { (0..<CategoryEntity.colorSlotCount).contains($0.colorIndex) })
        #expect(Set(seed.map(\.sortIndex)).count == seed.count)
        #expect(Set(seed.map(\.name)).count == seed.count)
    }
}
