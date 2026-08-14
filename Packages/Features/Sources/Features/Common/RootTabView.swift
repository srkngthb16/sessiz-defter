import DesignSystem
import SwiftUI

public struct RootTabView: View {
    let environment: AppEnvironment
    @State private var selection: Tab = .summary
    @State private var isComposerPresented = false
    @State private var isImportPresented = false
    /// Sheet'te yazılan işlem sekmelerdeki listeleri de tazelemeli; her kayıt bu
    /// sayacı artırır ve ekranların .task(id:) bağı yeniden çalışır.
    @State private var dataVersion = 0

    public enum Tab: Hashable {
        case summary, transactions, budgets, reports
    }

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    /// (+) butonu sekme çubuğunun üstünde duruyor; listelerin son satırını
    /// kapatmaması için içeriğe bu kadar alt boşluk bırakılır.
    static let composerClearance: CGFloat = 76

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                DashboardView(
                    environment: environment,
                    reloadToken: dataVersion,
                    onImport: { isImportPresented = true },
                    onAddManual: { isComposerPresented = true },
                    onSeeAllTransactions: { selection = .transactions })
                    .tabItem { Label("Özet", systemImage: "square.grid.2x2") }
                    .tag(Tab.summary)

                TransactionsView(environment: environment, reloadToken: dataVersion)
                    .tabItem { Label("İşlemler", systemImage: "list.bullet") }
                    .tag(Tab.transactions)

                ComingSoonView(title: "Bütçe", message: "Bütçe ekranı bir sonraki adımda geliyor.")
                    .tabItem { Label("Bütçe", systemImage: "chart.pie") }
                    .tag(Tab.budgets)

                ComingSoonView(title: "Raporlar", message: "Rapor ekranı bir sonraki adımda geliyor.")
                    .tabItem { Label("Raporlar", systemImage: "chart.bar") }
                    .tag(Tab.reports)
            }

            composerButton
        }
        .sheet(isPresented: $isComposerPresented) {
            TransactionEditorView(environment: environment) { dataVersion += 1 }
        }
        .sheet(isPresented: $isImportPresented) {
            ImportFlowView(environment: environment) { dataVersion += 1 }
        }
    }

    /// Tasarımda sekme çubuğunun ortasında (+) var; iOS TabView orta öğe taşımadığı için
    /// üstte duran bir buton olarak çizilir.
    private var composerButton: some View {
        Button {
            isComposerPresented = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.text.onBrand)
                .frame(width: 52, height: 52)
                .background(Color.brand.primary, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .accessibilityLabel("Yeni işlem ekle")
        .padding(.bottom, 58)
    }
}

struct ComingSoonView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s) {
                Text(message)
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.bg.canvas)
            .navigationTitle(title)
        }
    }
}
