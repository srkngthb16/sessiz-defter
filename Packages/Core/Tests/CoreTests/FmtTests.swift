import Foundation
import Testing
@testable import Core

@Suite("tr_TR biçimlendirme")
struct FmtTests {
    @Test("Tutar binlik ayracı nokta, ondalık virgül")
    func amountFormat() {
        #expect(Fmt.amount(Money(minorUnits: 4832075)) == "48.320,75")
        #expect(Fmt.amount(Money(minorUnits: 905)) == "9,05")
        #expect(Fmt.amount(Money(minorUnits: -84260)) == "842,60")
    }

    @Test("Para birimi simgesi önde ve kırılmaz boşlukla ayrık")
    func currencyFormat() {
        #expect(Fmt.currency(Money(minorUnits: 4832075)) == "₺\u{00A0}48.320,75")
    }

    @Test("Tarih gg.aa.yyyy")
    func dateFormat() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 12
        let date = calendar.date(from: components)!
        #expect(Fmt.date(date, calendar: calendar) == "12.08.2026")
        #expect(Fmt.dayHeader(date, calendar: calendar) == "12 Ağustos 2026 · Çarşamba")
    }

    @Test("Yüzde işareti sayının önünde")
    func percentFormat() {
        #expect(Fmt.percent(0.91) == "%91")
        #expect(Fmt.percent(1.20) == "%120")
    }

    @Test("Türkçe harf dönüşümü locale duyarlı")
    func turkishCasing() {
        #expect("İstanbul".trLower == "istanbul")
        #expect("ilgi".trUpper == "İLGİ")
    }

    @Test("Kuruş aritmetiği tam sayı üzerinde")
    func moneyArithmetic() {
        let sum = Money(minorUnits: 10) + Money(minorUnits: 20)
        #expect(sum.minorUnits == 30)
        #expect((-Money(minorUnits: 500)).isNegative)
    }
}
