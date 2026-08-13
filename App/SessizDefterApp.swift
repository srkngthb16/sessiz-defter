import DesignSystem
import SwiftUI

@main
struct SessizDefterApp: App {
    init() {
        Fonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Faz 3'te sekmeli yapı (Özet · İşlemler · Bütçe · Raporlar) buraya gelir.
struct RootView: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Sessiz Defter")
                .font(.sd.titleScreen)
                .foregroundStyle(Color.text.primary)
            Text("Faz 0 · tasarım sistemi iskeleti")
                .font(.sd.meta)
                .foregroundStyle(Color.text.muted)
            Text("₺\u{00A0}48.320,75")
                .font(.sd.balanceHero)
                .foregroundStyle(Color.text.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.canvas)
    }
}
