import Core
import Testing
@testable import DesignSystem

@Suite("VoiceOver etiketleri")
@MainActor
struct AccessibilityLabelTests {
    @Test("Gider tutarı işaretiyle okunur, kuruş sıfırsa okunmaz")
    func tutarOkunusu() {
        #expect(AmountText(amount: Money(minorUnits: 84_260), direction: .expense)
            .accessibilityLabel == "eksi 842 lira 60 kuruş")
        #expect(AmountText(amount: Money(minorUnits: 5_240_000), direction: .income)
            .accessibilityLabel == "artı 52.400 lira")
    }

    @Test("Bakiye yönsüz: işaret değerin kendisinden")
    func bakiye() {
        #expect(AmountText(amount: Money(minorUnits: -120_000), direction: .neutral,
                           style: .hero, showsSign: false)
            .accessibilityLabel == "eksi 1.200 lira")
    }

    @Test("Bütçe aşımı etikete eklenir")
    func asim() {
        let label = AmountText(amount: Money(minorUnits: 160_000), direction: .expense,
                               isCritical: true).accessibilityLabel
        #expect(label == "eksi 1.600 lira, bütçe aşıldı")
    }

    @Test("Hesap maskesi okunabilir hâle gelir")
    func maske() {
        #expect(SpokenText.expandingAccountMask("Market · Ziraat ••3412")
                == "Market, Ziraat son dört hane 3412")
    }

    @Test("İşlem satırı tek etiket: açıklama, meta, tutar, kontrol rozeti")
    func satir() {
        let model = TransactionRow.Model(
            detail: "Migros Ataşehir",
            meta: "Market · Ziraat ••3412",
            amount: Money(minorUnits: 48_725),
            direction: .expense,
            categorySymbolName: "cart",
            categoryColorIndex: 0,
            needsReview: true)
        #expect(TransactionRow(model: model).accessibilityLabel
                == "Migros Ataşehir, Market, Ziraat son dört hane 3412, "
                + "eksi 487 lira 25 kuruş, kontrol gerekiyor")
    }
}
