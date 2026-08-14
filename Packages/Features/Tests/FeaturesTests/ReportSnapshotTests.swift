import Core
import DesignSystem
import Domain
import SnapshotSupport
import SwiftUI
import Testing
@testable import Features

@Suite(.serialized)
struct ReportSnapshotTests {
    init() { Fonts.register() }
    static let suiteName = "ReportSnapshotTests"

    @MainActor
    @Test("E3 — raporlar")
    func raporlar() async throws {
        let model = ReportsModel(environment: await Fixtures.environment(withBudgets: true))
        await model.load()
        try Snapshot.verify(
            ReportsHost(state: model.state),
            name: "e3-raporlar", suite: Self.suiteName,
            size: CGSize(width: 393, height: 900))
    }
}

@MainActor
struct ReportModelTests {
    @Test("Trend altı ay, karşılaştırma ve işyerleri dolu")
    func icerik() async {
        let model = ReportsModel(environment: await Fixtures.environment(withBudgets: true))
        await model.load()
        guard case .loaded(let content) = model.state else {
            Issue.record("dolu durum bekleniyordu")
            return
        }
        #expect(content.points.count == 6)
        #expect(content.points.last?.label == "Ağu")
        #expect(content.points.last?.income.minorUnits == 5_240_000)
        #expect(content.currentLabel == "Ağu")
        #expect(content.previousLabel == "Tem")
        #expect(content.merchants.isEmpty == false)
        #expect(content.comparisons.isEmpty == false)
    }

    @Test("Ölçek değişince nokta sayısı değişir")
    func olcek() async {
        let model = ReportsModel(environment: await Fixtures.environment(withBudgets: true))
        model.scale = .quarter
        await model.load()
        guard case .loaded(let content) = model.state else {
            Issue.record("dolu durum bekleniyordu")
            return
        }
        #expect(content.points.count == 4)
        #expect(content.points.last?.label == "Ç3")
    }

    @Test("Veri yoksa boş durum")
    func bos() async {
        let model = ReportsModel(environment: await Fixtures.environment(seeded: false))
        await model.load()
        guard case .empty = model.state else {
            Issue.record("boş durum bekleniyordu")
            return
        }
    }

    @Test("Eksen etiketi kısaltması tr_TR ondalık ayracını kullanır")
    func eksenEtiketi() {
        #expect(ReportsScreen.compact(999) == "999")
        #expect(ReportsScreen.compact(38_900) == "38,9K")
        #expect(ReportsScreen.compact(214_860) == "215K")
    }
}

private struct ReportsHost: View {
    let state: ReportsModel.State
    @State private var scale: ReportScale = .month

    var body: some View {
        NavigationStack {
            ReportsScreen(state: state, scale: $scale)
                .navigationTitle("Raporlar")
        }
    }
}
