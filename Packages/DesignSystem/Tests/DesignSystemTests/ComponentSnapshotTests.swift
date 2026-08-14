import Core
import SnapshotSupport
import SwiftUI
import Testing
@testable import DesignSystem

@Suite(.serialized)
struct ComponentSnapshotTests {
    init() { Fonts.register() }
    static let suiteName = "ComponentSnapshotTests"

    @MainActor
    @Test("AmountText — hero, satır ve özet biçimleri")
    func amountText() throws {
        try Snapshot.verify(
            AmountGallery(), name: "amount-text", suite: Self.suiteName,
            size: CGSize(width: 393, height: 420))
    }

    @MainActor
    @Test("TransactionRow — normal, kritik, incelenecek")
    func transactionRow() throws {
        try Snapshot.verify(
            RowGallery(), name: "transaction-row", suite: Self.suiteName,
            size: CGSize(width: 393, height: 340))
    }

    @MainActor
    @Test("BudgetBar — yolunda, limite yakın, aşıldı")
    func budgetBar() throws {
        try Snapshot.verify(
            BudgetGallery(), name: "budget-bar", suite: Self.suiteName,
            size: CGSize(width: 393, height: 460))
    }

    @MainActor
    @Test("CategoryBadge — 12 renk yuvası")
    func categoryBadge() throws {
        try Snapshot.verify(
            BadgeGallery(), name: "category-badge", suite: Self.suiteName,
            size: CGSize(width: 393, height: 200))
    }

    @MainActor
    @Test("EmptyState — ilk açılış ve filtre sonucu boş")
    func emptyState() throws {
        try Snapshot.verify(
            EmptyStateGallery(), name: "empty-state", suite: Self.suiteName,
            size: CGSize(width: 393, height: 720))
    }

    @MainActor
    @Test("Skeleton — yükleme iskeleti")
    func skeleton() throws {
        try Snapshot.verify(
            SkeletonGallery(), name: "skeleton", suite: Self.suiteName,
            size: CGSize(width: 393, height: 260))
    }

    /// Renk kapalıyken tutarlar nötre düşer, ayrım kalın işaret ve ikonla taşınır.
    @MainActor
    @Test("Renksiz ayrım açıkken satır hâlâ okunur")
    func differentiateWithoutColor() throws {
        try Snapshot.verify(
            RowGallery().environment(\.differentiateWithoutColorOverride, true),
            name: "transaction-row-renksiz", suite: Self.suiteName,
            variants: [.light, .dark],
            size: CGSize(width: 393, height: 340))
    }
}

// MARK: - Galeriler

private struct GalleryBackground<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.bg.canvas)
    }
}

private struct AmountGallery: View {
    var body: some View {
        GalleryBackground {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Toplam net varlık")
                            .font(.sd.caption).foregroundStyle(Color.text.muted)
                        AmountText(amount: Money(minorUnits: 21_486_040),
                                   direction: .neutral, style: .hero, showsSign: false)
                        HStack(spacing: Spacing.s) {
                            AmountText(amount: Money(minorUnits: 6_240_000),
                                       direction: .income, style: .summary)
                            AmountText(amount: Money(minorUnits: 3_894_785),
                                       direction: .expense, style: .summary)
                        }
                    }
                }
                Card {
                    VStack(alignment: .trailing, spacing: Spacing.s) {
                        AmountText(amount: Money(minorUnits: 2_450_000), direction: .income)
                        AmountText(amount: Money(minorUnits: 84_260), direction: .expense)
                        AmountText(amount: Money(minorUnits: 125_000), direction: .transfer)
                        AmountText(amount: Money(minorUnits: 124_000), direction: .expense,
                                   isCritical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(Spacing.l)
        }
    }
}

private struct RowGallery: View {
    var body: some View {
        GalleryBackground {
            VStack(spacing: 0) {
                TransactionRow(model: .init(
                    detail: "Maaş ödemesi", meta: "Maaş · Ziraat ••3412",
                    amount: Money(minorUnits: 5_240_000), direction: .income,
                    categorySymbolName: "banknote", categoryColorIndex: 3))
                Divider().overlay(Color.border.divider)
                TransactionRow(model: .init(
                    detail: "Migros Ataşehir", meta: "Market · Ziraat ••3412",
                    amount: Money(minorUnits: 84_260), direction: .expense,
                    categorySymbolName: "cart", categoryColorIndex: 0))
                Divider().overlay(Color.border.divider)
                TransactionRow(model: .init(
                    detail: "Papara → Ziraat", meta: "Transfer · hesaplar arası",
                    amount: Money(minorUnits: 125_000), direction: .transfer,
                    categorySymbolName: "arrow.left.arrow.right", categoryColorIndex: 11))
                Divider().overlay(Color.border.divider)
                TransactionRow(model: .init(
                    detail: "Bi Nevi Deli Fişek", meta: "Yeme-içme · 12 Ağu · bütçe aşıldı",
                    amount: Money(minorUnits: 124_000), direction: .expense,
                    categorySymbolName: "fork.knife", categoryColorIndex: 10,
                    isCritical: true))
                Divider().overlay(Color.border.divider)
                TransactionRow(model: .init(
                    detail: "PAPARA ODEME ISTANBUL", meta: "Transfer? · güven %52",
                    amount: Money(minorUnits: 125_000), direction: .expense,
                    categorySymbolName: "questionmark", categoryColorIndex: 11,
                    needsReview: true))
            }
        }
    }
}

private struct BudgetGallery: View {
    var body: some View {
        GalleryBackground {
            VStack(spacing: Spacing.l) {
                row("Ulaşım", spent: 5_453_10, limit: 8_000_00, ratio: 0.68,
                    note: "Yolunda · kalan 2.546,90 ₺")
                row("Market", spent: 10_905_40, limit: 12_000_00, ratio: 0.91,
                    note: "Limite yakın · günlük 57,60 ₺")
                row("Eğlence", spent: 3_116_20, limit: 2_600_00, ratio: 1.20,
                    note: "516,20 ₺ aşıldı · limiti gözden geçir")
            }
            .padding(Spacing.l)
        }
    }

    private func row(_ title: String, spent: Int, limit: Int,
                     ratio: Double, note: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.sd.titleSection).foregroundStyle(Color.text.primary)
                    Spacer()
                    Text(Fmt.percent(ratio))
                        .font(.sd.amountRow)
                        .foregroundStyle(BudgetBar.State.from(ratio: ratio).tint)
                }
                BudgetBar(ratio: ratio)
                HStack(spacing: Spacing.xs) {
                    Text(Fmt.amount(Money(minorUnits: spent)))
                        .font(.sd.amountRow).foregroundStyle(Color.text.primary)
                    Text("/ \(Fmt.amount(Money(minorUnits: limit))) ₺")
                        .font(.sd.meta).foregroundStyle(Color.text.muted)
                }
                Text(note).font(.sd.meta).foregroundStyle(Color.text.secondary)
            }
        }
    }
}

private struct BadgeGallery: View {
    var body: some View {
        GalleryBackground {
            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(0..<3) { row in
                    HStack(spacing: Spacing.s) {
                        ForEach(0..<4) { column in
                            CategoryBadge(symbolName: "circle.fill",
                                          colorIndex: row * 4 + column)
                        }
                    }
                }
                HStack(spacing: Spacing.m) {
                    DirectionIcon(direction: .income)
                    DirectionIcon(direction: .expense)
                    DirectionIcon(direction: .transfer)
                }
            }
            .padding(Spacing.l)
        }
    }
}

private struct EmptyStateGallery: View {
    var body: some View {
        GalleryBackground {
            VStack(spacing: Spacing.l) {
                EmptyState(
                    kind: .firstRun,
                    title: "Defter henüz boş",
                    message: "Bir PDF ekstre yükleyin; işlemler cihazda ayrıştırılıp kategorilenir. İsterseniz elle de başlayabilirsiniz.",
                    footnote: "Yüklenen dosya cihazdan çıkmaz"
                ) {
                    PrimaryButton("PDF ekstre yükle", systemImage: "doc.badge.plus") {}
                    SecondaryButton("Manuel işlem ekle", systemImage: "plus") {}
                }
                EmptyState(
                    kind: .noResults,
                    title: "Bu filtreyle eşleşen işlem yok",
                    message: "“kira” aramasını Nakit hesabı ve Faturalar kategorisiyle birlikte denediniz. Filtrelerden birini kaldırmayı deneyin."
                ) {
                    PrimaryButton("Filtreleri temizle") {}
                    SecondaryButton("Tüm hesaplarda ara") {}
                }
            }
        }
    }
}

private struct SkeletonGallery: View {
    var body: some View {
        GalleryBackground {
            VStack(alignment: .leading, spacing: Spacing.l) {
                Card {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Skeleton(width: 120, height: 12, isAnimated: false)
                        Skeleton(width: 220, height: 40, isAnimated: false)
                    }
                }
                TransactionRowSkeleton(isAnimated: false)
                TransactionRowSkeleton(isAnimated: false)
            }
            .padding(Spacing.l)
        }
    }
}
