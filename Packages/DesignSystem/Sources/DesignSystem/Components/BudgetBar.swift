import SwiftUI

/// Bütçe çubuğu. %100'ü aşan kısım çapraz taramayla gösterilir — aşım renkten değil
/// dokudan da okunur. Çubuk hiçbir kademede metin barındırmaz; yüzde üst satırdadır.
public struct BudgetBar: View {
    public enum State: Sendable {
        case onTrack
        case warning   // %80 eşiği
        case exceeded  // %100 üstü

        public static func from(ratio: Double) -> State {
            if ratio > 1 { return .exceeded }
            if ratio >= 0.8 { return .warning }
            return .onTrack
        }

        public var tint: Color {
            switch self {
            case .onTrack: .brand.primary
            case .warning: .finance.warning
            case .exceeded: .finance.critical
            }
        }
    }

    let ratio: Double
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(ratio: Double) { self.ratio = max(0, ratio) }

    private var state: State { .from(ratio: ratio) }

    private var height: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? Metrics.budgetBarHeightLarge : Metrics.budgetBarHeight
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            // Aşımda çubuk dolu kabul edilir; aşan pay taralı bölge olarak ölçeklenir.
            let filledRatio = min(ratio, 1)
            let overflowRatio = ratio > 1 ? min((ratio - 1) / ratio, 1) : 0

            ZStack(alignment: .leading) {
                Capsule().fill(Color.bg.subtle)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(state.tint)
                        .frame(width: width * (filledRatio - overflowRatio))
                    if overflowRatio > 0 {
                        DiagonalHatch(color: state.tint)
                            .frame(width: width * overflowRatio)
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Çapraz tarama: aşım payını renk dışında bir kanalla da işaretler.
struct DiagonalHatch: View {
    let color: Color
    var spacing: CGFloat = 5
    var lineWidth: CGFloat = 2.5

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(color.opacity(0.28)))
            var offset = -size.height
            while offset < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(color),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                offset += spacing + lineWidth
            }
        }
    }
}
