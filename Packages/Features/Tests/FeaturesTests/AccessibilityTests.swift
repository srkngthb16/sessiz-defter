import Core
import Domain
import Foundation
import Testing
@testable import Features

@Suite("Ekran okunuşları")
struct AccessibilityTests {
    @Test("Bakiye kartı tek cümle")
    func bakiyeKarti() {
        let label = SpokenSummary.netWorth(Money(minorUnits: 4_770_967),
                                           monthNet: Money(minorUnits: 2_531_207),
                                           accountCount: 1)
        #expect(label == "Toplam net varlık 47.709 lira 67 kuruş, "
                + "bu ay artı 25.312 lira 7 kuruş, 1 hesap")
    }

    @Test("Ayın neti eksiyse 'eksi' okunur")
    func eksiNet() {
        let label = SpokenSummary.netWorth(Money(minorUnits: 100_000),
                                           monthNet: Money(minorUnits: -84_260),
                                           accountCount: 2)
        #expect(label.contains("bu ay eksi 842 lira 60 kuruş"))
    }

    private func status(spent: Int, limit: Int) -> BudgetStatus {
        BudgetStatus(budget: BudgetEntity(categoryID: UUID(),
                                          limit: Money(minorUnits: limit),
                                          startDate: Date()),
                     spent: Money(minorUnits: spent),
                     effectiveLimit: Money(minorUnits: limit),
                     daysRemaining: 15)
    }

    @Test("Aşılan bütçe: durum, oran, tutarlar ve aşım")
    func asilanButce() {
        let label = SpokenSummary.budget(status(spent: 160_000, limit: 140_000),
                                         categoryName: "Ulaşım")
        #expect(label == "Ulaşım bütçesi aşıldı, yüzde 114, harcanan 1.600 lira, "
                + "limit 1.400 lira, 200 lira aşıldı")
    }

    @Test("Limite yakın bütçede kalan okunur")
    func yakinButce() {
        let label = SpokenSummary.budget(status(spent: 112_155, limit: 120_000),
                                         categoryName: "Market")
        #expect(label.contains("Market bütçesi limite yakın"))
        #expect(label.contains("kalan 78 lira 45 kuruş"))
    }

    @Test("Dağılım satırı: ad, tutar, pay")
    func dagilimSatiri() {
        #expect(SpokenSummary.breakdownRow(name: "Ev",
                                           amount: Money(minorUnits: 1_800_000),
                                           share: 0.78)
                == "Ev 18.000 lira, yüzde 78")
    }

    @Test("Grafik özeti: en yüksek, en düşük ve son dönem")
    func grafikOzeti() {
        let points = [
            (label: "Haz", income: Money(minorUnits: 500_000),
             expense: Money(minorUnits: 300_000)),
            (label: "Tem", income: Money(minorUnits: 480_000),
             expense: Money(minorUnits: 610_000)),
            (label: "Ağu", income: Money(minorUnits: 520_000),
             expense: Money(minorUnits: 420_000))
        ]
        let summary = SpokenSummary.trend(points: points)
        #expect(summary.contains("3 dönem"))
        #expect(summary.contains("En yüksek gider Tem, 6.100 lira"))
        #expect(summary.contains("En düşük gider Haz, 3.000 lira"))
        #expect(summary.contains("Son dönem Ağu, gelir 5.200 lira, gider 4.200 lira"))
    }

    @Test("Boş grafikte özet çökmez")
    func bosGrafik() {
        #expect(SpokenSummary.trend(points: []) == "Grafikte veri yok")
    }
}
