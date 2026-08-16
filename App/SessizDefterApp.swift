import DesignSystem
import Domain
import Features
import Persistence
import SwiftUI

@main
struct SessizDefterApp: App {
    @State private var bootstrap = Bootstrap()

    init() {
        Fonts.register()
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.bg.canvas)
                    .task { await bootstrap.start() }
            case .ready(let environment, let settings, let backup):
                AppRootView(environment: environment, settings: settings, backup: backup)
            case .failed(let message):
                StoreFailureView(message: message)
            }
        }
    }
}

/// Kalıcılık kabı açılışta bir kez kurulur. Açılamazsa kullanıcıya sessizce boş
/// bir defter göstermek yerine hata gösterilir: veri kaybı izlenimi vermemeli.
@Observable
@MainActor
final class Bootstrap {
    enum State {
        case loading
        case ready(AppEnvironment, AppSettings, BackupService)
        case failed(String)
    }

    private(set) var state: State = .loading

    func start() async {
        do {
            let container = try StoreFactory.makeContainer()
            let store = PersistenceStore(modelContainer: container)
            // Arama sütunu 10.2'de eklendi; ondan önce yazılmış kayıtlarda boş
            // kalıyor ve arama onları bulamıyor. Tarama defterin tamamını gezdiği
            // için bir kez çalışır; sonraki yazımlar sütunu kendisi dolduruyor.
            let backfillKey = "searchIndex.backfilled.v1"
            if !UserDefaults.standard.bool(forKey: backfillKey) {
                try await store.backfillSearchIndex()
                UserDefaults.standard.set(true, forKey: backfillKey)
            }
            state = .ready(
                AppEnvironment(
                    transactions: store.transactions,
                    accounts: store.accounts,
                    categories: store.categories,
                    budgets: store.budgets,
                    categoryRules: store.categoryRules,
                    importBatches: store.importBatches,
                    parserProfiles: store.parserProfiles),
                AppSettings(),
                BackupService(store: store))
        } catch {
            state = .failed(String(describing: error))
        }
    }
}

struct StoreFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: Spacing.m) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.finance.critical)
            Text("Yerel defter açılamadı")
                .font(.sd.titleSection)
                .foregroundStyle(Color.text.primary)
            Text(message)
                .font(.sd.meta)
                .foregroundStyle(Color.text.muted)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.canvas)
    }
}
