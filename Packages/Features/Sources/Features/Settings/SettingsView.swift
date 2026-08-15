import Core
import DesignSystem
import Domain
import SwiftUI
import UniformTypeIdentifiers

/// F1 — Ayarlar.
public struct SettingsView: View {
    let environment: AppEnvironment
    let settings: AppSettings
    let appLock: any AppLocking
    let backup: (any BackupServing)?

    @State private var counts = Counts()
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var passwordPrompt: PasswordPrompt?
    @State private var exportDocument: BackupDocument?
    @State private var message: String?

    struct Counts {
        var transactions = 0
        var accounts = 0
        var budgets = 0
        var rules = 0
        var profiles = 0
    }

    struct PasswordPrompt: Identifiable {
        enum Purpose { case export, restore(URL) }
        let id = UUID()
        let purpose: Purpose
    }

    public init(environment: AppEnvironment, settings: AppSettings,
                appLock: any AppLocking = SystemAppLock(),
                backup: (any BackupServing)? = nil) {
        self.environment = environment
        self.settings = settings
        self.appLock = appLock
        self.backup = backup
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Bu uygulama internete bağlanmaz")
                            .font(.sd.titleSection)
                            .foregroundStyle(Color.text.primary)
                        Text("\(counts.transactions) işlem, \(counts.accounts) hesap ve \(counts.budgets) bütçe yalnızca bu telefonda saklanıyor.")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    NavigationLink("Mahremiyet raporu") {
                        PrivacyReportView(counts: counts)
                    }
                }

                Section("Güvenlik") {
                    Toggle("\(appLock.biometryName) kilidi",
                           isOn: Binding(get: { settings.isLockEnabled },
                                         set: { settings.isLockEnabled = $0 }))
                    Toggle("Arka planda gizle",
                           isOn: Binding(get: { settings.hidesContentInSwitcher },
                                         set: { settings.hidesContentInSwitcher = $0 }))
                    Picker("Otomatik kilit",
                           selection: Binding(get: { settings.autoLockDelay },
                                              set: { settings.autoLockDelay = $0 })) {
                        ForEach(AppSettings.AutoLockDelay.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Veri") {
                    Button("Yedek dışa aktar") {
                        passwordPrompt = PasswordPrompt(purpose: .export)
                    }
                    Button("Yedekten geri yükle") { isImporting = true }
                    NavigationLink("İçe aktarma kuralları") {
                        RulesView(environment: environment)
                    }
                    NavigationLink("Kategoriler") {
                        CategoryManagementView(environment: environment)
                    }
                }

                Section("Görünüm") {
                    Picker("Tema", selection: Binding(get: { settings.appearance },
                                                      set: { settings.appearance = $0 })) {
                        ForEach(AppSettings.Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("Para birimi", value: "₺ TRY")
                }

                Section {
                    NavigationLink {
                        DeleteEverythingView(environment: environment, counts: counts)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Tüm verileri sil")
                                .foregroundStyle(Color.finance.critical)
                            Text("geri alınamaz")
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.muted)
                        }
                    }
                }

                if let message {
                    Section { Text(message).font(.sd.meta) }
                }

                Section {
                    LabeledContent("Sürüm", value: AppVersion().displayString)
                } footer: {
                    Text("Sessiz Defter · çevrimdışı kişisel finans defteri")
                        .font(.sd.caption)
                }
            }
            .navigationTitle("Ayarlar")
            .task { await loadCounts() }
            .sheet(item: $passwordPrompt) { prompt in
                BackupPasswordSheet(purpose: prompt.purpose) { password in
                    Task { await handle(prompt.purpose, password: password) }
                }
            }
            .fileExporter(isPresented: $isExporting,
                          document: exportDocument,
                          contentType: .data,
                          defaultFilename: BackupFile.suggestedName(
                            for: environment.now(), calendar: environment.calendar)) { result in
                message = (try? result.get()) != nil
                    ? "Yedek dosyaya yazıldı." : "Yedek yazılamadı."
                exportDocument = nil
            }
            .fileImporter(isPresented: $isImporting,
                          allowedContentTypes: [.data]) { result in
                if let url = try? result.get() {
                    passwordPrompt = PasswordPrompt(purpose: .restore(url))
                }
            }
        }
    }

    private func loadCounts() async {
        counts.transactions = (try? await environment.transactions.count(matching: .all)) ?? 0
        counts.accounts = (try? await environment.accounts.all(includeArchived: true).count) ?? 0
        counts.budgets = (try? await environment.budgets.all(includeArchived: true).count) ?? 0
        counts.rules = (try? await environment.categoryRules.all())?.count ?? 0
        counts.profiles = ((try? await environment.parserProfiles?.all()) ?? [])?.count ?? 0
    }

    private func handle(_ purpose: PasswordPrompt.Purpose, password: String) async {
        guard let backup else { return }
        switch purpose {
        case .export:
            do {
                let archive = try await backup.makeArchive()
                let sealed = try PasswordCrypto.encrypt(try BackupArchive.encode(archive),
                                                        password: password)
                exportDocument = BackupDocument(data: sealed)
                isExporting = true
            } catch PasswordCrypto.Failure.weakPassword {
                message = "Parola en az \(PasswordCrypto.minimumPasswordLength) karakter olmalı."
            } catch {
                message = "Yedek hazırlanamadı."
            }
        case .restore(let url):
            do {
                // Güvenlik kapsamlı kaynak: erişim açıkça açılıp kapatılmalı.
                let needsScope = url.startAccessingSecurityScopedResource()
                defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                let sealed = try Data(contentsOf: url)
                let plain = try PasswordCrypto.decrypt(sealed, password: password)
                try await backup.restore(try BackupArchive.decode(plain))
                await loadCounts()
                message = "Yedek geri yüklendi."
            } catch PasswordCrypto.Failure.wrongPassword {
                message = "Parola hatalı ya da dosya bozuk."
            } catch {
                message = "Geri yükleme başarısız."
            }
        }
    }
}

/// Yedek dosyası düz veri olarak dışa aktarılır; içerik zaten şifreli.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupPasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let purpose: SettingsView.PasswordPrompt.Purpose
    let onSubmit: (String) -> Void

    @State private var password = ""

    private var isExport: Bool {
        if case .export = purpose { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Parola", text: $password)
                } footer: {
                    Text(isExport
                         ? "Yedek bu parolayla şifrelenir. Parolayı kaybederseniz dosya açılamaz — kurtarma yolu yoktur."
                         : "Yedeği oluştururken kullandığınız parolayı girin.")
                }
            }
            .navigationTitle(isExport ? "Yedek parolası" : "Yedeği aç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isExport ? "Şifrele" : "Aç") {
                        onSubmit(password)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(password.count < PasswordCrypto.minimumPasswordLength)
                }
            }
        }
    }
}
