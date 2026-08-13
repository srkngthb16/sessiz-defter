import Foundation
import Testing
@testable import Core

@Suite("Mükerrer hash")
struct DuplicateHashTests {
    static func date(_ day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return calendar.date(from: DateComponents(
            year: 2026, month: 8, day: day, hour: hour))!
    }

    @Test("Aynı gün, aynı tutar, aynı açıklama aynı hash'i verir")
    func stabilHash() {
        let a = DuplicateHash.make(date: Self.date(12, hour: 9),
                                   amount: Money(minorUnits: 84260), detail: "Migros Ataşehir")
        let b = DuplicateHash.make(date: Self.date(12, hour: 21),
                                   amount: Money(minorUnits: 84260), detail: "Migros Ataşehir")
        #expect(a == b)
    }

    @Test("Boşluk, noktalama ve harf durumu farkı hash'i değiştirmez")
    func normalizasyon() {
        let a = DuplicateHash.make(date: Self.date(12), amount: Money(minorUnits: 84260),
                                   detail: "MIGROS  ATASEHIR/İSTANBUL")
        let b = DuplicateHash.make(date: Self.date(12), amount: Money(minorUnits: 84260),
                                   detail: "migros atasehir istanbul")
        #expect(a == b)
    }

    @Test("Tutar veya gün farkı hash'i değiştirir")
    func ayrisma() {
        let base = DuplicateHash.make(date: Self.date(12), amount: Money(minorUnits: 84260),
                                      detail: "Migros")
        #expect(base != DuplicateHash.make(date: Self.date(13),
                                           amount: Money(minorUnits: 84260), detail: "Migros"))
        #expect(base != DuplicateHash.make(date: Self.date(12),
                                           amount: Money(minorUnits: 84261), detail: "Migros"))
    }

    @Test("İşaret hash'i etkilemez — yön ayrı alanda taşınır")
    func isaretsiz() {
        let pozitif = DuplicateHash.make(date: Self.date(12), amount: Money(minorUnits: 84260),
                                         detail: "Migros")
        let negatif = DuplicateHash.make(date: Self.date(12), amount: Money(minorUnits: -84260),
                                         detail: "Migros")
        #expect(pozitif == negatif)
    }

    @Test("Türkçe harfler ASCII'ye katlanır — ekstre ile elle giriş aynı hash'i versin")
    func turkceNormalizasyon() {
        #expect(DuplicateHash.normalizedDetail("İstanbul ışık") == "ISTANBUL ISIK")
        #expect(DuplicateHash.normalizedDetail("Ataşehir Şubesi") == "ATASEHIR SUBESI")
        #expect(DuplicateHash.make(date: Self.date(12), amount: Money(minorUnits: 100),
                                   detail: "Migros Ataşehir")
             == DuplicateHash.make(date: Self.date(12), amount: Money(minorUnits: 100),
                                   detail: "MIGROS ATASEHIR"))
    }
}
