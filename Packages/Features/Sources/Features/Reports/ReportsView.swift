import Charts
import Core
import DesignSystem
import Domain
import SwiftUI

/// E3 — raporlar. Grafikte bir döneme dokunulunca okuma paneli o dönemi gösterir.
public struct ReportsView: View {
    @State private var model: ReportsModel
    let environment: AppEnvironment
    let reloadToken: Int

    public init(environment: AppEnvironment, reloadToken: Int = 0) {
        self.environment = environment
        self.reloadToken = reloadToken
        _model = State(initialValue: ReportsModel(environment: environment))
    }

    public var body: some View {
        NavigationStack {
            ReportsScreen(state: model.state, scale: $model.scale)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: RootTabView.composerClearance)
                }
                .navigationTitle("Raporlar")
                .task(id: reloadToken) { await model.load() }
                .task(id: model.scale) { await model.load() }
        }
    }
}

/// Saf çizim katmanı; snapshot testleri bunu kullanır.
public struct ReportsScreen: View {
    let state: ReportsModel.State
    @Binding var scale: ReportScale
    @State private var selectedLabel: String?

    public init(state: ReportsModel.State, scale: Binding<ReportScale>) {
        self.state = state
        _scale = scale
    }

    public var body: some View {
        ScrollView {
            switch state {
            case .loading:
                VStack(spacing: Spacing.l) {
                    Card { Skeleton(height: 180) }
                    Card { Skeleton(height: 120) }
                }
                .padding(Spacing.l)
            case .empty:
                EmptyState(
                    kind: .firstRun,
                    title: "Rapor için veri yok",
                    message: "İşlem ekledikçe gelir–gider trendi, dönem karşılaştırması ve en çok harcadığınız yerler burada birikir."
                ) { EmptyView() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let content):
                VStack(spacing: Spacing.l) {
                    scalePicker
                    trendCard(content)
                    // Tek hesaplı defterde kırılımın anlatacağı bir şey yok.
                    if content.accounts.count > 1 { accountCard(content) }
                    if !content.comparisons.isEmpty { comparisonCard(content) }
                    if !content.merchants.isEmpty { merchantCard(content) }
                }
                .padding(Spacing.l)
            }
        }
        .background(Color.bg.canvas)
    }

    private var scalePicker: some View {
        Picker("Ölçek", selection: $scale) {
            ForEach(ReportScale.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private func trendCard(_ content: ReportsModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader(title: "Gelir · gider trendi")
                Text("son \(content.points.count) dönem · dokunarak değer oku")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)

                readout(for: content)

                Chart {
                    ForEach(content.points) { point in
                        BarMark(x: .value("Dönem", point.label),
                                y: .value("Gelir", point.income.minorUnits / 100),
                                width: .fixed(10))
                            .position(by: .value("Tür", "Gelir"))
                            .foregroundStyle(Color.finance.income)
                        BarMark(x: .value("Dönem", point.label),
                                y: .value("Gider", point.expense.minorUnits / 100),
                                width: .fixed(10))
                            .position(by: .value("Tür", "Gider"))
                            .foregroundStyle(Color.finance.expense)
                    }
                    if let selectedLabel {
                        RuleMark(x: .value("Seçili", selectedLabel))
                            .foregroundStyle(Color.border.strong)
                            .zIndex(-1)
                    }
                }
                // Çubukları tek tek dinlemek eğilimi anlatmıyor: grafik tek öğe,
                // değeri sözlü özet.
                .accessibilityElement()
                .accessibilityLabel("Gelir ve gider trendi grafiği")
                .accessibilityValue(SpokenSummary.trend(points: content.points.map {
                    (label: $0.label, income: $0.income, expense: $0.expense)
                }))
                .chartXSelection(value: $selectedLabel)
                .chartLegend(.hidden)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.border.divider)
                        AxisValueLabel {
                            if let amount = value.as(Int.self) {
                                Text(Self.compact(amount))
                                    .font(.sd.caption)
                                    .foregroundStyle(Color.text.muted)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.sd.caption)
                                    .foregroundStyle(Color.text.muted)
                            }
                        }
                    }
                }
                .frame(height: 180)

                HStack(spacing: Spacing.m) {
                    legend("Gelir", Color.finance.income, .income)
                    legend("Gider", Color.finance.expense, .expense)
                }
            }
        }
    }

    /// Okuma paneli: seçim yoksa son dönem gösterilir.
    /// Üç tutar tek satıra sığmıyor (beş haneli rakamlar kırpılıyordu); dönem ve net
    /// üstte, gelir ve gider altta.
    private func readout(for content: ReportsModel.Content) -> some View {
        let point = content.points.first { $0.label == selectedLabel } ?? content.points.last
        // Erişilebilirlik kademelerinde dört tutar yan yana sığmıyor ve
        // "+₺ 48…" diye kırpılıyordu; eşik geçilince hepsi alt alta.
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            AdaptiveStack(spacing: Spacing.s) {
                Text(point?.label ?? "—")
                    .font(.sd.titleSection)
                    .foregroundStyle(Color.text.primary)
                Spacer(minLength: Spacing.s)
                if let point {
                    Text("Net")
                        .font(.sd.caption)
                        .foregroundStyle(Color.text.muted)
                    AmountText(amount: point.net.magnitude,
                               direction: point.net.isNegative ? .expense : .income,
                               style: .summary)
                }
            }
            if let point {
                AdaptiveStack(spacing: Spacing.m) {
                    AmountText(amount: point.income, direction: .income, style: .summary)
                    AmountText(amount: point.expense, direction: .expense, style: .summary)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func legend(_ title: String, _ color: Color,
                        _ direction: TransactionDirectionStyle) -> some View {
        HStack(spacing: Spacing.xs) {
            DirectionIcon(direction: direction)
            Text(title)
                .font(.sd.meta)
                .foregroundStyle(color)
        }
    }

    private func comparisonCard(_ content: ReportsModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader(title: "Dönem karşılaştırma")
                Text("\(content.currentLabel) / \(content.previousLabel)")
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
                ForEach(content.comparisons) { comparison in
                    HStack(spacing: Spacing.s) {
                        CategoryBadge(
                            symbolName: content.categories.symbolName(comparison.categoryID),
                            colorIndex: content.categories.colorIndex(comparison.categoryID),
                            size: 26)
                        Text(content.categories.name(comparison.categoryID))
                            .font(.sd.bodyItem)
                            .foregroundStyle(Color.text.primary)
                        Spacer(minLength: Spacing.s)
                        Text(Fmt.amount(comparison.current))
                            .font(.sd.amountRow)
                            .foregroundStyle(Color.text.primary)
                        changeLabel(comparison)
                    }
                }
            }
        }
    }

    private func changeLabel(_ comparison: CategoryComparison) -> some View {
        Group {
            if let ratio = comparison.changeRatio {
                // Artış her zaman kötü değil; ayrım renge değil yön işaretine biner.
                Text((ratio >= 0 ? "+" : "\u{2212}") + Fmt.percent(abs(ratio)))
                    .foregroundStyle(ratio >= 0 ? Color.finance.expense : Color.finance.income)
            } else {
                Text("yeni")
                    .foregroundStyle(Color.text.muted)
            }
        }
        .font(.sd.meta)
        .frame(width: 62, alignment: .trailing)
    }

    /// Banka bazlı kırılım. Tutarlar erişilebilirlik kademesinde alt alta geçsin
    /// diye AdaptiveStack kullanılıyor: yan yana yazıldığında XXXL boyutta
    /// kırpılıyorlardı.
    private func accountCard(_ content: ReportsModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader(title: "Hesaplara göre")
                ForEach(content.accounts) { item in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(spacing: Spacing.s) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.sd.bodyItem)
                                    .foregroundStyle(Color.text.primary)
                                if let masked = item.maskedNumber {
                                    Text(masked)
                                        .font(.sd.meta)
                                        .foregroundStyle(Color.text.muted)
                                        .accessibilityLabel("son dört hane \(masked.suffix(4))")
                                }
                            }
                            Spacer(minLength: Spacing.s)
                            AmountText(amount: item.net.magnitude,
                                       direction: item.net.isNegative ? .expense : .income,
                                       style: .row)
                        }
                        AdaptiveStack(spacing: Spacing.s) {
                            accountLeg("Gelir", item.income, .income)
                            accountLeg("Gider", item.expense, .expense)
                            if item.transferCount > 0 {
                                Text("\(item.transferCount) transfer")
                                    .font(.sd.meta)
                                    .foregroundStyle(Color.text.muted)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func accountLeg(_ title: String, _ amount: Money,
                            _ direction: TransactionDirection) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.sd.meta)
                .foregroundStyle(Color.text.secondary)
            Text(Fmt.amount(amount))
                .font(.sd.meta)
                .foregroundStyle(direction == .income
                    ? Color.finance.income : Color.finance.expense)
        }
    }

    private func merchantCard(_ content: ReportsModel.Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.m) {
                SectionHeader(title: "En çok harcanan yerler")
                ForEach(Array(content.merchants.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: Spacing.s) {
                        Text("\(index + 1)")
                            .font(.sd.caption)
                            .foregroundStyle(Color.text.muted)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.name)
                                .font(.sd.bodyItem)
                                .foregroundStyle(Color.text.primary)
                            Text("\(item.transactionCount) işlem")
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.muted)
                        }
                        Spacer(minLength: Spacing.s)
                        Text(Fmt.amount(item.total))
                            .font(.sd.amountRow)
                            .foregroundStyle(Color.text.primary)
                    }
                }
            }
        }
    }

    /// Eksen etiketi: "38,9K"
    static func compact(_ amount: Int) -> String {
        guard abs(amount) >= 1000 else { return "\(amount)" }
        let thousands = Double(amount) / 1000
        let formatter = NumberFormatter()
        formatter.locale = TurkishLocale.locale
        formatter.maximumFractionDigits = thousands >= 100 ? 0 : 1
        return (formatter.string(from: NSNumber(value: thousands)) ?? "") + "K"
    }
}
