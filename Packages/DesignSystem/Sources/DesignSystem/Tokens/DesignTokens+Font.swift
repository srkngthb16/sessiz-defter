import SwiftUI

public enum TypeFace {
    // Gömülü statik ağırlıkların aile adları. Tasarım dosyasındaki "IBMPlexMono"
    // yazımı CoreText'te çözülmez (PostScript adı IBMPlexMono-Regular, aile adı
    // "IBM Plex Mono"); aile adı kullanılır, aksi halde sessizce sistem fontuna düşer.
    public static let ui   = "Archivo"
    public static let data = "IBM Plex Mono"
}

extension Font {
    // Dynamic Type'a bağlı özel font — relativeTo şart,
    // aksi halde ölçek kullanıcı ayarını takip etmez.
    private static func scaled(_ name: String, _ size: CGFloat,
                               _ style: TextStyle) -> Font {
        .custom(name, size: size, relativeTo: style)
    }

    public static let balanceHero  = scaled(TypeFace.data, 44, .largeTitle)
                                        .weight(.medium).monospacedDigit()
    public static let titleScreen  = scaled(TypeFace.ui,   28, .title).weight(.bold)
    public static let titleSection = scaled(TypeFace.ui,   17, .headline).weight(.semibold)
    public static let bodyItem     = scaled(TypeFace.ui,   16, .body).weight(.medium)
    public static let amountRow    = scaled(TypeFace.data, 16, .body)
                                        .weight(.medium).monospacedDigit()
    public static let meta         = scaled(TypeFace.ui,   13, .footnote)
    public static let button       = scaled(TypeFace.ui,   16, .body).weight(.semibold)
    // Tasarım dosyasında token adı "caption". SwiftUI'da Font.caption zaten var;
    // aynı adı kullanmak her çağrı yerinde "ambiguous use of 'font'" veriyor.
    // Ad çakışmasının nasıl çözüleceği kullanıcıya soruldu (Faz 0 açık sorusu).
    public static let captionLabel = scaled(TypeFace.ui,   11, .caption2).weight(.medium)
}

// Sistem-öncelikli set (Set 1) — dosya gerekmez:
extension Font {
    public static let balanceHeroSystem =
        Font.system(size: 44, weight: .semibold, design: .default)
            .monospacedDigit()
    public static let amountRowSystem =
        Font.system(.body, design: .default).monospacedDigit()
}
