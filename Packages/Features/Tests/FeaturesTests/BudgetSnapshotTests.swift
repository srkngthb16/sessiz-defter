import Core
import DesignSystem
import Domain
import SnapshotSupport
import SwiftUI
import Testing
@testable import Features

@Suite(.serialized)
struct BudgetSnapshotTests {
    init() { Fonts.register() }
    static let suiteName = "BudgetSnapshotTests"

    @MainActor
    @Test("E1 — bütçe durumları")
    func butceListesi() async throws {
        let model = BudgetsModel(environment: await Fixtures.environment(withBudgets: true))
        await model.load()
        guard case .loaded(let content) = model.state else {
            Issue.record("dolu durum bekleniyordu")
            return
        }
        try Snapshot.verify(
            BudgetGallery(content: content),
            name: "e1-butceler", suite: Self.suiteName,
            size: CGSize(width: 393, height: 700))
    }
}

@MainActor
struct ModelBudgetTests {
    @Test("Bütçe durumları eşiklere göre hesaplanır ve sıralanır")
    func butceDurumlari() async {
        let model = BudgetsModel(environment: await Fixtures.environment(withBudgets: true))
        await model.load()
        guard case .loaded(let content) = model.state else {
            Issue.record("dolu durum bekleniyordu")
            return
        }
        #expect(content.statuses.count == 2)
        // Aşan bütçe önce gelir.
        #expect(content.statuses.first?.state == .exceeded)
        #expect(content.statuses.last?.state == .warning)
        #expect(content.overview.totalLimit.minorUnits == 1_460_000)
        #expect(content.overview.totalSpent.minorUnits == 1_402_160)
    }

    @Test("Bütçe yoksa boş durum")
    func butceYok() async {
        let model = BudgetsModel(environment: await Fixtures.environment())
        await model.load()
        guard case .empty = model.state else {
            Issue.record("boş durum bekleniyordu")
            return
        }
    }

    @Test("Dashboard yalnızca dikkat isteyen bütçeleri gösterir")
    func dashboardButceleri() async {
        let model = DashboardModel(environment: await Fixtures.environment(withBudgets: true))
        await model.load()
        guard case .loaded(let content) = model.state else {
            Issue.record("dolu durum bekleniyordu")
            return
        }
        #expect(content.budgets.count == 2)
        #expect(content.budgets.allSatisfy { $0.state != .onTrack })
    }
}

private struct BudgetGallery: View {
    let content: BudgetsModel.Content

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
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
                    }
                }
                ForEach(content.statuses) { status in
                    Card {
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            HStack {
                                Text(content.categories.name(status.budget.categoryID))
                                    .font(.sd.titleSection)
                                    .foregroundStyle(Color.text.primary)
                                Spacer()
                                Text("\(status.state.label) · \(Fmt.percent(status.ratio))")
                                    .font(.sd.meta)
                                    .foregroundStyle(status.state == .exceeded
                                                     ? Color.finance.critical
                                                     : Color.finance.warning)
                            }
                            BudgetBar(ratio: status.ratio)
                            Text("\(Fmt.amount(status.spent)) / \(Fmt.amount(status.effectiveLimit)) ₺")
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.muted)
                        }
                    }
                }
            }
            .padding(Spacing.l)
        }
        .background(Color.bg.canvas)
    }
}
