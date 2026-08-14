import SwiftUI

/// İki tip boş durum: defter hiç doldurulmamış (B1) ve filtre sonucu boş (D6).
public struct EmptyState<Actions: View>: View {
    public enum Kind {
        /// B1 — ilk açılış. Görsel alanı gerçek illüstrasyon bekliyor.
        case firstRun
        /// D6 — filtreyle eşleşen kayıt yok.
        case noResults
    }

    let kind: Kind
    let title: String
    let message: String
    let footnote: String?
    let actions: Actions

    public init(
        kind: Kind,
        title: String,
        message: String,
        footnote: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.footnote = footnote
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: Spacing.l) {
            if kind == .firstRun {
                placeholderArtwork
            } else {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.text.muted)
            }

            VStack(spacing: Spacing.s) {
                Text(title)
                    .font(.sd.titleSection)
                    .foregroundStyle(Color.text.primary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.s) { actions }

            if let footnote {
                Text(footnote)
                    .font(.sd.caption)
                    .foregroundStyle(Color.text.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }

    /// Tasarım notu: "defter + kapalı kutu" metaforu, tek çizgi, accent tek renk.
    /// Gerçek varlık henüz yok — üretimde değiştirilecek yer tutucu.
    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            .strokeBorder(Color.border.default, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .frame(height: 132)
            .overlay {
                VStack(spacing: Spacing.s) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Color.brand.primary)
                    Text("Yer tutucu · ilk açılış görseli")
                        .font(.sd.caption)
                        .foregroundStyle(Color.text.muted)
                }
            }
            .accessibilityHidden(true)
    }
}

/// Birincil eylem butonu: dolgu marka rengi, metin onBrand, en az 44 pt.
public struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.sd.button)
            .foregroundStyle(Color.text.onBrand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Metrics.minimumTapTarget)
            .padding(.vertical, Spacing.xs)
            .background(Color.brand.primary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
    }
}

public struct SecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.sd.button)
            .foregroundStyle(Color.text.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Metrics.minimumTapTarget)
            .padding(.vertical, Spacing.xs)
            .background(Color.bg.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .strokeBorder(Color.border.default, lineWidth: 1)
            }
        }
    }
}
