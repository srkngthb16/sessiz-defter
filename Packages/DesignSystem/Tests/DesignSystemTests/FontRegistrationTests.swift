import SwiftUI
import Testing
import UIKit
@testable import DesignSystem

/// Font adı çözülemezse UIKit sessizce sistem fontuna düşer ve tasarım bozulur;
/// bu yüzden kayıt ve çözümleme ayrı ayrı doğrulanır.
@Suite(.serialized)
struct FontRegistrationTests {
    init() { Fonts.register() }

    @Test("Gömülü 7 font dosyası bundle'da var")
    func dosyalarBundleda() {
        for name in Fonts.bundledFileNames {
            let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf")
            #expect(url != nil, "eksik font: \(name).ttf")
        }
    }

    @Test("Aile adları CoreText'te çözülür, sistem fontuna düşmez")
    func aileAdlariCozulur() {
        for family in [TypeFace.ui, TypeFace.data] {
            let font = UIFont(name: family, size: 16)
            #expect(font != nil, "çözülemedi: \(family)")
            #expect(font?.familyName == family, "beklenmeyen aile: \(font?.familyName ?? "-")")
        }
    }

    @Test("Tasarımın istediği ağırlıklar ailede mevcut")
    func agirliklarMevcut() {
        let archivo = Set(UIFont.fontNames(forFamilyName: TypeFace.ui))
        for face in ["Archivo-Regular", "Archivo-Medium", "Archivo-SemiBold", "Archivo-Bold"] {
            #expect(archivo.contains(face), "eksik: \(face) · mevcut: \(archivo.sorted())")
        }
        let plex = Set(UIFont.fontNames(forFamilyName: TypeFace.data))
        for face in ["IBMPlexMono-Regular", "IBMPlexMono-Medium", "IBMPlexMono-SemiBold"] {
            #expect(plex.contains(face), "eksik: \(face) · mevcut: \(plex.sorted())")
        }
    }

    @Test("₺ (U+20BA) ve Türkçe harfler her iki ailede glif taşır")
    func turkceGlifler() {
        for family in [TypeFace.ui, TypeFace.data] {
            let font = CTFontCreateWithName(family as CFString, 16, nil)
            let characters = Array("₺ğışçöüİĞŞÇÖÜ".unicodeScalars.flatMap { Array(String($0).utf16) })
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            let ok = CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
            #expect(ok, "\(family) bazı Türkçe/₺ gliflerini taşımıyor")
        }
    }
}
