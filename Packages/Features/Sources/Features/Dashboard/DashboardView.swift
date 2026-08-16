import Core
import DesignSystem
import Domain
import SwiftUI

public struct DashboardView: View {
    @State private var model: DashboardModel
    let environment: AppEnvironment
    let reloadToken: Int
    var onImport: () -> Void
    var onAddManual: () -> Void
    var onSeeAllTransactions: () -> Void
    var onSeeAllBudgets: () -> Void
    var onOpenSettings: () -> Void

    public init(
        environment: AppEnvironment,
        reloadToken: Int = 0,
        onImport: @escaping () -> Void = {},
        onAddManual: @escaping () -> Void = {},
        onSeeAllTransactions: @escaping () -> Void = {},
        onSeeAllBudgets: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.environment = environment
        self.reloadToken = reloadToken
        self.onImport = onImport
        self.onAddManual = onAddManual
        self.onSeeAllTransactions = onSeeAllTransactions
        self.onSeeAllBudgets = onSeeAllBudgets
        self.onOpenSettings = onOpenSettings
        _model = State(initialValue: DashboardModel(environment: environment))
    }

    public var body: some View {
        NavigationStack {
            DashboardScreen(state: model.state, onImport: onImport,
                            onAddManual: onAddManual,
                            onSeeAllTransactions: onSeeAllTransactions,
                            onSeeAllBudgets: onSeeAllBudgets,
                            calendar: environment.calendar)
                .navigationTitle("Özet")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onOpenSettings()
                        } label: {
                            Label("Ayarlar", systemImage: "gearshape")
                        }
                    }
                }
                .task(id: reloadToken) { await model.load() }
        }
    }
}

/// Saf çizim katmanı: durumu dışarıdan alır, kendi yüklemesi yoktur.
/// Snapshot testleri bu görünümü kullanır — asenkron yükleme referansı kararsız yapardı.
public struct DashboardScreen: View {
    let state: DashboardModel.State
    var onImport: () -> Void = {}
    var onAddManual: () -> Void = {}
    var onSeeAllTransactions: () -> Void = {}
    var onSeeAllBudgets: () -> Void = {}
    var calendar: Calendar = .current

    public init(
        state: DashboardModel.State,
        onImport: @escaping () -> Void = {},
        onAddManual: @escaping () -> Void = {},
        onSeeAllTransactions: @escaping () -> Void = {},
        onSeeAllBudgets: @escaping () -> Void = {},
        calendar: Calendar = .current
    ) {
        self.state = state
        self.onImport = onImport
        self.onAddManual = onAddManual
        self.onSeeAllTransactions = onSeeAllTransactions
        self.onSeeAllBudgets = onSeeAllBudgets
        self.calendar = calendar
    }

    public var body: some View {
        ScrollView {
            switch state {
            case .loading: loadingSkeleton
            case .empty: emptyState
            case .loaded(let content): loaded(content)
            }
        }
        .background(Color.bg.canvas)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: RootTabView.composerClearance)
        }
    }

    // MARK: B2 — yükleme iskeleti

    private var loadingSkeleton: some View {
        VStack(spacing: Spacing.l) {
            Card {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Skeleton(width: 130, height: 12)
                    Skeleton(width: 240, height: 44)
                    HStack(spacing: Spacing.s) {
                        Skeleton(height: 52, cornerRadius: Radius.control)
                        Skeleton(height: 52, cornerRadius: Radius.control)
                    }
                }
            }
            Card(padding: 0) {
                VStack(spacing: 0) {
                    TransactionRowSkeleton()
                    TransactionRowSkeleton()
                    TransactionRowSkeleton()
                }
            }
        }
        .padding(Spacing.l)
    }

    // MARK: B1 — boş durum

    private var emptyState: some View {
        EmptyState(
            kind: .firstRun,
            title: "Defter henüz boş",
            message: "Bir PDF ekstre yükleyin; işlemler cihazda ayrıştırılıp kategorilenir. İsterseniz elle de başlayabilirsiniz.",
            footnote: "Yüklenen dosya cihazdan çıkmaz"
        ) {
            PrimaryButton("PDF ekstre yükle", systemImage: "doc.badge.plus", action: onImport)
            SecondaryButton("Manuel işlem ekle", systemImage: "plus", action: onAddManual)
        }
    }

    // MARK: D1 — dolu

    private func loaded(_ content: DashboardModel.Content) -> some View {
        VStack(spacing: Spacing.l) {
            balanceCard(content)
            if !content.budgets.isEmpty { budgetCard(content) }
            if !content.breakdown.isEmpty { breakdownCard(content) }
            recentCard(content)
        }
        .padding(Spacing.l)
    }

    private func balanceCard(_ content: DashboardModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                // Başlık, bakiye ve ayın neti tek erişilebilirlik öğesi: ayrı ayrı
                // okununca "47.709,67" ile "25.312,07" arasındaki ilişki kayboluyor
                // ve "bu ay · 1 hesap" içindeki orta nokta ayraç olarak duyulmuyordu.
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Toplam net varlık")
                        .font(.sd.caption)
                        .foregroundStyle(Color.text.muted)
                    AmountText(amount: content.netWorth, direction: .neutral,
                               style: .hero, showsSign: false)
                    // Erişilebilirlik kademelerinde yan yana kalırsa tutar kırpılıp
                    // "+₺ 25.…" oluyordu; eşik TransactionRow ile aynı.
                    AdaptiveStack(spacing: Spacing.xs) {
                        AmountText(amount: content.summary.net.magnitude,
                                   direction: content.summary.net.isNegative
                                       ? .expense : .income,
                                   style: .summary)
                        Text("bu ay · \(content.accountCount) hesap")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(SpokenSummary.netWorth(content.netWorth,
                                                           monthNet: content.summary.net,
                                                           accountCount: content.accountCount))
                AdaptiveStack(spacing: Spacing.s) {
                    summaryTile("Gelir", content.summary.income, .income)
                    summaryTile("Gider", content.summary.expense, .expense)
                }
            }
        }
    }

    /// D1 — yalnızca dikkat isteyen bütçeler; tamamı Bütçe sekmesinde.
    private func budgetCard(_ content: DashboardModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader(title: "Bütçe · \(content.periodTitle)",
                              actionTitle: "Tümü", action: onSeeAllBudgets)
                ForEach(content.budgets) { status in
                    budgetRow(status, categories: content.categories)
                }
            }
        }
    }

    private func budgetRow(_ status: BudgetStatus,
                           categories: CategoryLookup) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(categories.name(status.budget.categoryID))
                    .font(.sd.bodyItem)
                    .foregroundStyle(Color.text.primary)
                Spacer()
                Text(Fmt.percent(status.ratio))
                    .font(.sd.amountRow)
                    .foregroundStyle(status.state == .exceeded
                                     ? Color.finance.critical
                                     : Color.finance.warning)
            }
            BudgetBar(ratio: status.ratio)
            Text("\(Fmt.amount(status.spent)) / \(Fmt.amount(status.effectiveLimit)) ₺")
                .font(.sd.meta)
                .foregroundStyle(Color.text.muted)
        }
        // "1.600,00 / 1.400,00 ₺" seslendirmede bölme işlemi gibi duyuluyordu.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpokenSummary.budget(
            status, categoryName: categories.name(status.budget.categoryID)))
    }

    private func summaryTile(_ title: String, _ amount: Money,
                             _ direction: TransactionDirectionStyle) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                DirectionIcon(direction: direction)
                Text(title)
                    .font(.sd.caption)
                    .foregroundStyle(direction.tint)
            }
            AmountText(amount: amount, direction: direction, style: .summary)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(direction.surface, in: RoundedRectangle(cornerRadius: Radius.control,
                                                            style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpokenSummary.summaryTile(title, amount,
                                                      isIncome: direction == .income))
    }

    private func breakdownCard(_ content: DashboardModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader(title: "Kategori dağılımı")
                Text("\(content.periodTitle) · gider")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
                ForEach(content.breakdown) { item in
                    HStack(spacing: Spacing.s) {
                        CategoryBadge(
                            symbolName: item.isRemainder
                                ? "ellipsis"
                                : content.categories.symbolName(item.categoryID),
                            colorIndex: content.categories.colorIndex(item.categoryID),
                            size: 26)
                        Text(item.isRemainder
                             ? "Diğer kategoriler"
                             : content.categories.name(item.categoryID))
                            .font(.sd.bodyItem)
                            .foregroundStyle(Color.text.primary)
                        Spacer(minLength: Spacing.s)
                        Text(Fmt.amount(item.amount))
                            .font(.sd.amountRow)
                            .foregroundStyle(Color.text.primary)
                        Text(Fmt.percent(item.share))
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(SpokenSummary.breakdownRow(
                        name: item.isRemainder
                            ? "Diğer kategoriler"
                            : content.categories.name(item.categoryID),
                        amount: item.amount,
                        share: item.share))
                }
            }
        }
    }

    private func recentCard(_ content: DashboardModel.Content) -> some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                SectionHeader(title: "Son işlemler", actionTitle: "Tümü",
                              action: onSeeAllTransactions)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                ForEach(content.recent) { transaction in
                    Divider().overlay(Color.border.divider)
                    TransactionRow(model: transaction.rowModel(
                        categories: content.categories, accounts: content.accounts))
                }
            }
        }
    }
}
