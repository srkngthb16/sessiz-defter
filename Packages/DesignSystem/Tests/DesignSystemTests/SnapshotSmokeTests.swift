import SnapshotSupport
import SwiftUI
import Testing
@testable import DesignSystem

/// Snapshot altyapısının kendisini doğrular: 4 varyant çizilir, referanslarla karşılaştırılır.
/// Faz 2'de bileşen snapshot'ları aynı yardımcıyı kullanır.
@Suite(.serialized)
struct SnapshotSmokeTests {
    init() { Fonts.register() }

    @MainActor
    @Test("Token kartı 4 varyantta referansla eşleşir")
    func tokenKarti() throws {
        try Snapshot.verify(
            TokenProbe(),
            name: "token-karti",
            suite: "SnapshotSmokeTests",
            size: CGSize(width: 393, height: 320)
        )
    }
}

private struct TokenProbe: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Toplam bakiye")
                .font(.sd.caption)
                .foregroundStyle(Color.text.muted)
            Text("₺\u{00A0}48.320,75")
                .font(.sd.balanceHero)
                .foregroundStyle(Color.text.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            HStack(spacing: 10) {
                probe("Gelir", "+₺\u{00A0}24.500,00", Color.finance.income, Color.finance.incomeSurface)
                probe("Gider", "−₺\u{00A0}16.179,25", Color.finance.expense, Color.finance.expenseSurface)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.bg.surface)
    }

    private func probe(_ baslik: String, _ tutar: String, _ renk: Color, _ yuzey: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(baslik).font(.sd.caption).foregroundStyle(renk)
            Text(tutar).font(.sd.amountRow).foregroundStyle(renk)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(yuzey, in: RoundedRectangle(cornerRadius: 12))
    }
}
