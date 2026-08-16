import SwiftUI

/// B1 boş durum illüstrasyonu — tasarım notunun tarifi: "defter + kapalı kutu"
/// metaforu, tek çizgi, accent tek renk.
///
/// Varlık dosyası değil kod: PNG/PDF bir varlık dört varyantta (açık/koyu ×
/// standart/XXL) ayrı ayrı üretilmek zorunda kalırdı ve renk tokenlarını takip
/// edemezdi. Path olarak çizilince tema değişince kendisi dönüyor.
public struct LedgerBoxArtwork: View {
    /// Çizim 160×120'lik bir tuvalde tasarlandı; ölçek buradan hesaplanır.
    static let designSize = CGSize(width: 160, height: 120)

    let height: CGFloat

    public init(height: CGFloat = 120) {
        self.height = height
    }

    /// Çizgi kalınlığı ölçekle büyümez: illüstrasyon büyürken çizgi de kalınlaşınca
    /// "tek çizgi" karakteri kayboluyor.
    private var stroke: StrokeStyle {
        StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
    }

    public var body: some View {
        ZStack {
            LedgerBoxOutline().stroke(Color.border.strong, style: stroke)
            LedgerBoxAccent().stroke(Color.brand.primary, style: stroke)
        }
        .frame(width: height * (Self.designSize.width / Self.designSize.height),
               height: height)
        .accessibilityHidden(true)
    }
}

/// Gövde çizgileri: kapalı defter (solda) ve kapalı kutu (sağda), taban hizası ortak.
struct LedgerBoxOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let t = ArtworkTransform(rect: rect)

        // Defter — kapak
        path.addRoundedRect(
            in: t.rect(x: 14, y: 22, width: 58, height: 84),
            cornerSize: CGSize(width: t.scaled(6), height: t.scaled(6)))
        // Sırt: kapaktan içeride, defteri "kapalı" gösteren tek detay.
        path.move(to: t.point(26, 22))
        path.addLine(to: t.point(26, 106))
        // Sayfa bloğunun kenarı
        path.move(to: t.point(66, 30))
        path.addLine(to: t.point(66, 98))

        // Kutu — ön yüz
        path.move(to: t.point(78, 64))
        path.addLine(to: t.point(140, 64))
        path.addLine(to: t.point(140, 106))
        path.addLine(to: t.point(78, 106))
        path.closeSubpath()
        // Kapak (üst yüz) ve sağ yan yüz: kutu kapalı, açık ağız çizilmiyor.
        path.move(to: t.point(78, 64))
        path.addLine(to: t.point(90, 52))
        path.addLine(to: t.point(152, 52))
        path.addLine(to: t.point(140, 64))
        path.move(to: t.point(152, 52))
        path.addLine(to: t.point(152, 94))
        path.addLine(to: t.point(140, 106))

        return path
    }
}

/// Accent çizgileri: defterin ayracı ve kutunun bandı. İkisi de tek renk.
struct LedgerBoxAccent: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let t = ArtworkTransform(rect: rect)

        // Ayraç: kapağın üstünden sarkar, ucu çentikli.
        path.move(to: t.point(46, 22))
        path.addLine(to: t.point(46, 56))
        path.addLine(to: t.point(52, 50))
        path.addLine(to: t.point(58, 56))
        path.addLine(to: t.point(58, 22))

        // Bant: kapaktan ön yüze kesintisiz iner.
        path.move(to: t.point(121, 52))
        path.addLine(to: t.point(109, 64))
        path.addLine(to: t.point(109, 106))

        return path
    }
}

/// 160×120 tasarım tuvalini çizim alanına oranı bozmadan oturtur.
private struct ArtworkTransform {
    let scale: CGFloat
    let origin: CGPoint

    init(rect: CGRect) {
        let design = LedgerBoxArtwork.designSize
        scale = min(rect.width / design.width, rect.height / design.height)
        origin = CGPoint(x: rect.midX - design.width * scale / 2,
                         y: rect.midY - design.height * scale / 2)
    }

    func scaled(_ value: CGFloat) -> CGFloat { value * scale }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }

    func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(origin: point(x, y),
               size: CGSize(width: width * scale, height: height * scale))
    }
}
