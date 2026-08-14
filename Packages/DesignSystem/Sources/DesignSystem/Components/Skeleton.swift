import SwiftUI

/// Yükleme iskeleti. Yalnızca yerel sorgu 200 ms'yi geçerse gösterilir; daha hızlı
/// dönerse içerik doğrudan çizilir — titremeyi önlemek için.
public struct Skeleton: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    /// Snapshot testi parıltıyı kapatır: animasyon fazı zamana bağlı olduğu için
    /// açık bırakılırsa referans görüntü her koşuda başka çıkar.
    let isAnimated: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = -1

    public init(width: CGFloat? = nil, height: CGFloat = 14,
                cornerRadius: CGFloat = Radius.pill, isAnimated: Bool = true) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.isAnimated = isAnimated
    }

    private var showsShimmer: Bool { isAnimated && !reduceMotion }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.bg.subtle)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .overlay { if showsShimmer { shimmer } }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
            .onAppear {
                guard showsShimmer else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmerPhase = 2
                }
            }
    }

    private var shimmer: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, Color.bg.surface.opacity(0.55), .clear],
                startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.6)
                .offset(x: shimmerPhase * proxy.size.width)
        }
    }
}

/// B2 — dashboard yükleme iskeleti.
public struct TransactionRowSkeleton: View {
    let isAnimated: Bool

    public init(isAnimated: Bool = true) { self.isAnimated = isAnimated }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            Skeleton(width: Metrics.badgeSize, height: Metrics.badgeSize,
                     cornerRadius: Radius.badge, isAnimated: isAnimated)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Skeleton(width: 160, height: 15, isAnimated: isAnimated)
                Skeleton(width: 110, height: 12, isAnimated: isAnimated)
            }
            Spacer(minLength: Spacing.s)
            Skeleton(width: 88, height: 15, isAnimated: isAnimated)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }
}
