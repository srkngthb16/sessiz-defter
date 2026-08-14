import SwiftUI

/// Kategori rengi yalnızca dolgu ve rozet olarak kullanılır; etiket metni daima
/// text.primary'dir. Bu yüzden rozet metin taşımaz, ikon taşır.
public struct CategoryBadge: View {
    let symbolName: String
    let colorIndex: Int
    let direction: TransactionDirectionStyle
    /// Yön ikonu rozetin üstünde değil, satırda ayrı ve sabit konumdadır;
    /// rozet yalnızca kategoriyi anlatır.
    let size: CGFloat

    public init(
        symbolName: String,
        colorIndex: Int,
        direction: TransactionDirectionStyle = .expense,
        size: CGFloat = Metrics.badgeSize
    ) {
        self.symbolName = symbolName
        self.colorIndex = colorIndex
        self.direction = direction
        self.size = size
    }

    private var fill: Color {
        Color.category.all[max(0, min(colorIndex, Color.category.all.count - 1))]
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(Color.white)
            }
            .accessibilityHidden(true)
    }
}

/// ↙ ↗ ⇄ — kategori ikonundan ayrı, sabit konumda, 16 pt.
/// Gelir/gider ayrımının renkten bağımsız ikinci katmanı.
public struct DirectionIcon: View {
    let direction: TransactionDirectionStyle

    @Environment(\.accessibilityDifferentiateWithoutColor)
    private var systemDifferentiateWithoutColor
    @Environment(\.differentiateWithoutColorOverride) private var differentiateOverride

    private var differentiateWithoutColor: Bool {
        differentiateOverride ?? systemDifferentiateWithoutColor
    }

    public init(direction: TransactionDirectionStyle) {
        self.direction = direction
    }

    public var body: some View {
        if let symbolName = direction.symbolName {
            Image(systemName: symbolName)
                .font(.system(size: Metrics.directionIconSize,
                              weight: differentiateWithoutColor ? .bold : .medium))
                .foregroundStyle(differentiateWithoutColor ? Color.text.primary : direction.tint)
                .frame(width: Metrics.directionIconSize + Spacing.xs,
                       height: Metrics.directionIconSize + Spacing.xs)
                .accessibilityHidden(true)
        }
    }
}
