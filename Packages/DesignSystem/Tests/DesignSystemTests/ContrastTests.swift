import SwiftUI
import Testing
import UIKit
@testable import DesignSystem

/// Tasarım dosyasındaki kontrast tablosu spesifikasyondur: token değeri değişirse
/// bu test düşer. Tüm oranlar bg.surface üzerinde ölçülür.
@Suite("Kontrast oranları (WCAG 2.2)")
struct ContrastTests {
    struct Beklenen {
        let ad: String
        let renk: Color
        let acik: Double
        let koyu: Double
    }

    static let metinTokenlari: [Beklenen] = [
        .init(ad: "text.primary",   renk: Color.text.primary,   acik: 17.12, koyu: 14.30),
        .init(ad: "text.secondary", renk: Color.text.secondary, acik: 7.26,  koyu: 8.48),
        .init(ad: "text.muted",     renk: Color.text.muted,     acik: 4.85,  koyu: 5.36),
        .init(ad: "text.disabled",  renk: Color.text.disabled,  acik: 3.05,  koyu: 3.48)
    ]

    static let finansTokenlari: [Beklenen] = [
        .init(ad: "finance.income",   renk: Color.finance.income,   acik: 5.41, koyu: 7.81),
        .init(ad: "finance.expense",  renk: Color.finance.expense,  acik: 6.57, koyu: 7.31),
        .init(ad: "finance.transfer", renk: Color.finance.transfer, acik: 5.88, koyu: 7.50),
        .init(ad: "finance.warning",  renk: Color.finance.warning,  acik: 5.14, koyu: 8.77),
        .init(ad: "finance.critical", renk: Color.finance.critical, acik: 6.00, koyu: 6.39)
    ]

    static let kenarlikTokenlari: [Beklenen] = [
        .init(ad: "border.divider", renk: Color.border.divider,  acik: 1.25, koyu: 1.23),
        .init(ad: "border.default", renk: Color.border.default,  acik: 1.49, koyu: 1.53)
    ]

    static let tolerans = 0.05

    @Test("Metin tokenları dokümandaki oranı tutturur", arguments: metinTokenlari)
    func metinKontrasti(_ beklenen: Beklenen) {
        dogrula(beklenen)
    }

    @Test("Semantik finans renkleri dokümandaki oranı tutturur", arguments: finansTokenlari)
    func finansKontrasti(_ beklenen: Beklenen) {
        dogrula(beklenen)
    }

    @Test("Kenarlık tokenları dokümandaki oranı tutturur", arguments: kenarlikTokenlari)
    func kenarlikKontrasti(_ beklenen: Beklenen) {
        dogrula(beklenen)
    }

    @Test("Gövde metni taşıyan tokenlar AA (4.5:1) eşiğini geçer")
    func aaEsigi() {
        for beklenen in Self.metinTokenlari.prefix(3) + Self.finansTokenlari {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let oran = WCAG.contrastRatio(beklenen.renk, Color.bg.surface, style: style)
                #expect(oran >= 4.5, "\(beklenen.ad) \(style == .light ? "açık" : "koyu"): \(oran)")
            }
        }
    }

    @Test("Marka dolgusu üzerindeki metin AA geçer")
    func markaDolgusu() {
        let acik = WCAG.contrastRatio(Color.text.onBrand, Color.brand.primary, style: .light)
        let koyu = WCAG.contrastRatio(Color.text.onBrand, Color.brand.primary, style: .dark)
        #expect(abs(acik - 5.08) < Self.tolerans, "açık: \(acik)")
        #expect(abs(koyu - 8.57) < Self.tolerans, "koyu: \(koyu)")
    }

    @Test("Koyu modda 12 kategori rengi yüzey üstünde en az 3.6:1")
    func kategoriKoyuMod() {
        for (index, renk) in Color.category.all.enumerated() {
            let oran = WCAG.contrastRatio(renk, Color.bg.surface, style: .dark)
            #expect(oran >= 3.6, "kategori \(index + 1): \(oran)")
        }
    }

    private func dogrula(_ beklenen: Beklenen) {
        let acik = WCAG.contrastRatio(beklenen.renk, Color.bg.surface, style: .light)
        let koyu = WCAG.contrastRatio(beklenen.renk, Color.bg.surface, style: .dark)
        #expect(abs(acik - beklenen.acik) < Self.tolerans,
                "\(beklenen.ad) açık: \(acik), beklenen \(beklenen.acik)")
        #expect(abs(koyu - beklenen.koyu) < Self.tolerans,
                "\(beklenen.ad) koyu: \(koyu), beklenen \(beklenen.koyu)")
    }
}

extension ContrastTests.Beklenen: CustomTestStringConvertible {
    var testDescription: String { ad }
}
