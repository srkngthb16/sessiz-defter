import Core
import SwiftUI
import Testing
@testable import DesignSystem

@Suite("Tutar gösterimi")
struct AmountTextTests {
    @Test("Yönsüz tutarda eksi bakiye işaretli gösterilir")
    func negatifBakiye() {
        let negative = AmountText(amount: Money(minorUnits: -25_000),
                                  direction: .neutral, style: .hero, showsSign: false)
        #expect(negative.debugSignPrefix == "\u{2212}")

        let positive = AmountText(amount: Money(minorUnits: 25_000),
                                  direction: .neutral, style: .hero, showsSign: false)
        #expect(positive.debugSignPrefix == "")
    }

    @Test("Yönlü tutarlarda işaret yönden gelir")
    func yonluIsaretler() {
        #expect(AmountText(amount: Money(minorUnits: 100), direction: .income)
            .debugSignPrefix == "+")
        #expect(AmountText(amount: Money(minorUnits: 100), direction: .expense)
            .debugSignPrefix == "\u{2212}")
        #expect(AmountText(amount: Money(minorUnits: 100), direction: .transfer)
            .debugSignPrefix == "")
        #expect(AmountText(amount: Money(minorUnits: 100), direction: .expense, showsSign: false)
            .debugSignPrefix == "")
    }
}
