import SwiftUI

/// Tek katman derinlik: canvas → kart (1 pt kenarlık, 16 pt köşe) → sheet (22 pt köşe).
/// Gölge yalnızca sheet ve FAB'de; kart gölge taşımaz.
public struct Card<Content: View>: View {
    let padding: CGFloat
    let content: Content

    public init(padding: CGFloat = Spacing.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.bg.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Color.border.divider, lineWidth: 1)
            }
    }
}

/// Kart içinde bölüm başlığı: "Son işlemler" + "Tümü ›"
public struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.sd.titleSection)
                .foregroundStyle(Color.text.primary)
            Spacer(minLength: Spacing.s)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 2) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    }
                    .font(.sd.meta)
                    .foregroundStyle(Color.brand.primary)
                }
                .frame(minHeight: Metrics.minimumTapTarget)
            }
        }
    }
}
