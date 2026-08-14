import Core
import DesignSystem
import Domain
import SwiftUI

/// E1 — bütçeler.
public struct BudgetsView: View {
    @State private var model: BudgetsModel
    @State private var editing: BudgetEntity?
    @State private var isCreating = false
    @State private var localVersion = 0

    let environment: AppEnvironment
    let reloadToken: Int

    public init(environment: AppEnvironment, reloadToken: Int = 0) {
        self.environment = environment
        self.reloadToken = reloadToken
        _model = State(initialValue: BudgetsModel(environment: environment))
    }

    public var body: some View {
        NavigationStack {
            content
                .background(Color.bg.canvas)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: RootTabView.composerClearance)
                }
                .navigationTitle("Bütçe")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Ekle") { isCreating = true }
                    }
                }
                .task(id: reloadToken) { await model.load() }
                .task(id: localVersion) { await model.load() }
                .sheet(isPresented: $isCreating) {
                    BudgetEditorView(environment: environment) { localVersion += 1 }
                }
                .sheet(item: $editing) { budget in
                    BudgetEditorView(environment: environment, editing: budget) {
                        localVersion += 1
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            ScrollView {
                VStack(spacing: Spacing.l) {
                    Card { Skeleton(width: 200, height: 40) }
                    Card { Skeleton(height: 60) }
                }
                .padding(Spacing.l)
            }
        case .empty:
            ScrollView {
                EmptyState(
                kind: .firstRun,
                    title: "Henüz bütçe yok",
                    message: "Kategori bazlı aylık limit koyun; %80'de uyarı, %100'de aşım işareti gelir.",
                    footnote: "Uyarılar cihazda üretilir"
                ) {
                    PrimaryButton("Bütçe ekle", systemImage: "plus") { isCreating = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .loaded(let content):
            ScrollView {
                VStack(spacing: Spacing.l) {
                    overviewCard(content)
                    ForEach(content.statuses) { status in
                        budgetCard(status, categories: content.categories)
                    }
                }
                .padding(Spacing.l)
            }
        }
    }

    private func overviewCard(_ content: BudgetsModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("\(content.periodTitle) · \(content.daysRemaining) gün kaldı")
                    .font(.sd.caption)
                    .foregroundStyle(Color.text.muted)
                AmountText(amount: content.overview.remaining.magnitude,
                           direction: .neutral, style: .hero, showsSign: false)
                Text("\(Fmt.amount(content.overview.totalLimit)) ₺ limitin kalanı")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.secondary)
                if let daily = content.overview.dailyAllowance {
                    HStack(spacing: Spacing.xs) {
                        Text(Fmt.amount(daily) + " ₺")
                            .font(.sd.amountRow)
                            .foregroundStyle(Color.text.primary)
                        Text("gün başına")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                }
            }
        }
    }

    private func budgetCard(_ status: BudgetStatus, categories: CategoryLookup) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    CategoryBadge(symbolName: categories.symbolName(status.budget.categoryID),
                                  colorIndex: categories.colorIndex(status.budget.categoryID),
                                  size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(categories.name(status.budget.categoryID))
                            .font(.sd.titleSection)
                            .foregroundStyle(Color.text.primary)
                        Text("\(status.state.label) · \(Fmt.percent(status.ratio))")
                            .font(.sd.meta)
                            .foregroundStyle(tint(for: status.state))
                    }
                    Spacer(minLength: Spacing.s)
                    if status.state == .exceeded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.finance.critical)
                    }
                }
                BudgetBar(ratio: status.ratio)
                HStack(spacing: Spacing.xs) {
                    Text(Fmt.amount(status.spent))
                        .font(.sd.amountRow)
                        .foregroundStyle(Color.text.primary)
                    Text("/ \(Fmt.amount(status.effectiveLimit)) ₺")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.muted)
                }
                Text(detailLine(status))
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
            .onTapGesture { editing = status.budget }
        }
        .contextMenu {
            Button("Limiti düzenle", systemImage: "pencil") { editing = status.budget }
            Button("Bütçeyi sil", systemImage: "trash", role: .destructive) {
                Task { await model.delete(status) }
            }
        }
    }

    private func detailLine(_ status: BudgetStatus) -> String {
        if let overspend = status.overspend {
            return "\(Fmt.amount(overspend)) ₺ aşıldı · limiti gözden geçir"
        }
        var text = "Kalan \(Fmt.amount(status.remaining)) ₺"
        if let daily = status.dailyAllowance {
            text += " · günlük \(Fmt.amount(daily)) ₺ harcanabilir"
        }
        return text
    }

    private func tint(for state: BudgetStatus.State) -> Color {
        switch state {
        case .onTrack: .finance.income
        case .warning: .finance.warning
        case .exceeded: .finance.critical
        }
    }
}

extension BudgetEntity: @retroactive Identifiable {}
