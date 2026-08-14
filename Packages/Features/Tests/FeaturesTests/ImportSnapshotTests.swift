import Core
import DesignSystem
import Domain
import ImportPipeline
import SnapshotSupport
import SwiftUI
import Testing
@testable import Features

@Suite(.serialized)
struct ImportSnapshotTests {
    init() { Fonts.register() }
    static let suiteName = "ImportSnapshotTests"

    @MainActor
    @Test("C2 — cihaz üzerinde işleniyor")
    func islenıyor() throws {
        try Snapshot.verify(
            ProcessingStep(stage: .parsingRows)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bg.canvas),
            name: "c2-isleniyor", suite: Self.suiteName,
            size: CGSize(width: 393, height: 420))
    }

    @MainActor
    @Test("C3 — onay satırları ve sayaçlar")
    func onaySatirlari() throws {
        try Snapshot.verify(
            ReviewGallery(),
            name: "c3-onay", suite: Self.suiteName,
            size: CGSize(width: 393, height: 420))
    }

    @MainActor
    @Test("C8 — taranmış PDF uyarısı")
    func taranmisPDF() async throws {
        let model = ImportModel(environment: await Fixtures.environment())
        try Snapshot.verify(
            ScannedStep(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.bg.canvas),
            name: "c8-taranmis", suite: Self.suiteName,
            size: CGSize(width: 393, height: 520))
    }
}

private struct ReviewGallery: View {
    static func row(_ detail: String, _ minorUnits: Int, _ kind: ImportDraftRow.Kind,
                    _ confidence: Double, selected: Bool) -> ImportDraftRow {
        ImportDraftRow(
            date: Fixtures.date(12), detail: detail, amount: Money(minorUnits: minorUnits),
            direction: .expense, categoryID: nil, confidence: confidence, kind: kind,
            isSelected: selected, lineNumber: 1, duplicateHash: "x")
    }

    var body: some View {
        VStack(spacing: 0) {
            ReviewCounters(draft: ImportDraft(
                fileName: "Ziraat_ekstre_agustos.pdf",
                formatIdentifier: "ziraat.vadesiz.v1", bankName: "Ziraat Bankası",
                rows: [
                    Self.row("A", 100, .automatic, 0.9, selected: true),
                    Self.row("B", 100, .needsReview, 0.5, selected: true),
                    Self.row("C", 100, .duplicate, 0.9, selected: false)
                ]))
            List {
                ImportRowView(row: Self.row("PAPARA ODEME ISTANBUL", 125_000,
                                            .needsReview, 0.52, selected: true),
                              categoryName: "Transfer", isChecked: true,
                              isSelectedForBulk: false)
                ImportRowView(row: Self.row("MIGROS ATASEHIR", 84_260,
                                            .automatic, 0.94, selected: true),
                              categoryName: "Market", isChecked: true,
                              isSelectedForBulk: true)
                ImportRowView(row: Self.row("SPOTIFY", 5_999, .duplicate, 0.9, selected: false),
                              categoryName: "Abonelik", isChecked: false,
                              isSelectedForBulk: false)
            }
            .listStyle(.insetGrouped)
        }
        .background(Color.bg.canvas)
    }
}
