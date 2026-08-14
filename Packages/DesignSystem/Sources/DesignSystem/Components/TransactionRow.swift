import Core
import SwiftUI

/// İşlem satırı. Gelir/gider ayrımı üç katmanla kodlanır: işaret + yön ikonu + renk.
/// .accessibility1'den itibaren ViewThatFits yatay düzeni dikeye çevirir.
public struct TransactionRow: View {
    public struct Model: Hashable, Sendable {
        public let detail: String
        /// "Market · Ziraat ••3412"
        public let meta: String
        public let amount: Money
        public let direction: TransactionDirectionStyle
        public let categorySymbolName: String
        public let categoryColorIndex: Int
        public let isCritical: Bool
        public let needsReview: Bool

        public init(
            detail: String,
            meta: String,
            amount: Money,
            direction: TransactionDirectionStyle,
            categorySymbolName: String,
            categoryColorIndex: Int,
            isCritical: Bool = false,
            needsReview: Bool = false
        ) {
            self.detail = detail
            self.meta = meta
            self.amount = amount
            self.direction = direction
            self.categorySymbolName = categorySymbolName
            self.categoryColorIndex = categoryColorIndex
            self.isCritical = isCritical
            self.needsReview = needsReview
        }
    }

    let model: Model

    public init(model: Model) { self.model = model }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontal
            vertical
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .background(model.isCritical ? Color.finance.criticalSurface : Color.bg.surface)
        .accessibilityElement(children: .combine)
    }

    private var horizontal: some View {
        HStack(spacing: Spacing.m) {
            leading
            texts
            Spacer(minLength: Spacing.s)
            AmountText(amount: model.amount, direction: model.direction,
                       style: .row, isCritical: model.isCritical)
        }
    }

    private var vertical: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                leading
                texts
            }
            AmountText(amount: model.amount, direction: model.direction,
                       style: .row, isCritical: model.isCritical)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var leading: some View {
        HStack(spacing: Spacing.s) {
            CategoryBadge(symbolName: model.isCritical
                            ? "exclamationmark.triangle.fill" : model.categorySymbolName,
                          colorIndex: model.categoryColorIndex,
                          direction: model.direction)
            DirectionIcon(direction: model.direction)
        }
    }

    private var texts: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.detail)
                .font(.sd.bodyItem)
                .foregroundStyle(Color.text.primary)
                // ViewThatFits adaylarını sınırsız genişlikte ölçüyor; bu olmadan
                // metin sarmak yerine tek satırda kalıp kırpılıyor. Dondurma değil,
                // tam tersi: dikeyde büyümeye izin verir.
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Spacing.xs) {
                if model.needsReview {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.finance.warning)
                }
                Text(model.meta)
                    .font(.sd.meta)
                    .foregroundStyle(model.isCritical ? Color.finance.expense : Color.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
