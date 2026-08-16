import SwiftUI

/// Standart kademelerde yatay, erişilebilirlik kademelerinde dikey yerleşim.
///
/// Eşik `ViewThatFits` ile değil doğrudan `dynamicTypeSize.isAccessibilitySize`
/// ile veriliyor: ViewThatFits adaylarını sarmasız genişlikte ölçtüğü için dar
/// kartlarda standart kademede bile dikey adayı seçiyordu (aynı gerekçe
/// `TransactionRow`'da da geçerli).
public struct AdaptiveStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let spacing: CGFloat
    let content: Content

    public init(spacing: CGFloat = Spacing.s, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}
