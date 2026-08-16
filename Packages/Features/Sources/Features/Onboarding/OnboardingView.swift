import Core
import DesignSystem
import Domain
import SwiftUI

/// A1–A3 — hesap oluşturma adımı yoktur; üç kart sonunda tek koruma Face ID.
public struct OnboardingView: View {
    let settings: AppSettings
    let appLock: any AppLocking
    /// Örnek defteri yazan iş. Onboarding repository tanımaz; yazma işi dışarıdan
    /// verilir ki ekran testte ve önizlemede veri katmanı olmadan da kurulabilsin.
    let loadSampleData: () async -> Void
    let onFinished: () -> Void

    @State private var page = 0
    @State private var wantsSampleData = false
    @State private var isFinishing = false

    public init(settings: AppSettings, appLock: any AppLocking = SystemAppLock(),
                loadSampleData: @escaping () async -> Void = {},
                onFinished: @escaping () -> Void) {
        self.settings = settings
        self.appLock = appLock
        self.loadSampleData = loadSampleData
        self.onFinished = onFinished
    }

    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                privacyPage.tag(0)
                onDevicePage.tag(1)
                lockPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
        .background(Color.bg.canvas)
    }

    private func header(_ step: Int, _ caption: String) -> some View {
        Text("\(step) / 3 · \(caption)")
            .font(.sd.caption)
            .foregroundStyle(Color.brand.primary)
    }

    private var privacyPage: some View {
        page(header: header(1, "Sessiz Defter"),
             title: "Verileriniz telefonunuzdan çıkmaz",
             message: "Sunucu yok, hesap yok, senkronizasyon yok. Uygulamanın ağ katmanı hiç yazılmadı — kapatılabilir bir ayar değil, olmayan bir özellik.") {
            Card {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Cihaz sınırı")
                        .font(.sd.caption)
                        .foregroundStyle(Color.text.muted)
                    Text("iPhone · Şifreli yerel depo")
                        .font(.sd.titleSection)
                        .foregroundStyle(Color.text.primary)
                    Text("Ekstreler, işlemler ve bütçeler yalnızca bu kutunun içinde yaşar.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.secondary)
                    ForEach(["Bulut", "Hesap", "Analitik", "Reklam kimliği"], id: \.self) { item in
                        HStack(spacing: Spacing.s) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.finance.critical)
                            Text(item)
                                .font(.sd.meta)
                                .foregroundStyle(Color.text.secondary)
                        }
                    }
                }
            }
        } actions: {
            PrimaryButton("Devam") { page = 1 }
        }
    }

    private var onDevicePage: some View {
        page(header: header(2, "Nasıl çalışır"),
             title: "Bankanızın PDF ekstresi yeter",
             message: "Ekstreyi Dosyalar'dan seçin. Metin çıkarma, banka formatı tanıma ve kategorileme tamamen bu telefonun işlemcisinde yapılır.") {
            Card {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    step(1, "PDF'i seçin", "Dosyalar uygulaması · yerel dosya")
                    step(2, "Cihazda ayrıştırılır", "Ağ trafiği oluşmaz · uçak modunda da çalışır")
                    step(3, "Siz onaylarsınız", "Düşük güvenli satırlar işaretli gelir")
                    Divider().overlay(Color.border.divider)
                    Text("Manuel giriş de her zaman açık: banka desteklenmiyorsa işlemleri elle ekleyebilirsiniz.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.secondary)
                }
            }
        } actions: {
            PrimaryButton("Devam") { page = 2 }
        }
    }

    private var lockPage: some View {
        page(header: header(3, "Tek koruma"),
             title: "Defterinizi \(appLock.biometryName) ile kilitleyin",
             message: "Şifre oluşturmanız gerekmez. Kilit tamamen cihazda doğrulanır; yedek olarak iPhone parolanız kullanılır.") {
            VStack(spacing: Spacing.m) {
                securityCard
                sampleDataCard
            }
        } actions: {
            PrimaryButton("\(appLock.biometryName)'yi etkinleştir") {
                Task {
                    // İzin akışı kullanıcı hâlâ ekrandayken çalışsın; reddedilirse
                    // kilit kapalı kalır ama uygulama kullanılabilir olmayı sürdürür.
                    if case .success = await appLock.authenticate(
                        reason: "Defterinizi kilitlemek için kimliğinizi doğrulayın") {
                        settings.isLockEnabled = true
                    }
                    await finish()
                }
            }
            .disabled(isFinishing)
            SecondaryButton("Şimdi değil") {
                settings.isLockEnabled = false
                Task { await finish() }
            }
            .disabled(isFinishing)
        }
    }

    private var securityCard: some View {
        Card {
            VStack(spacing: Spacing.m) {
                Toggle(isOn: Binding(get: { settings.isLockEnabled },
                                     set: { settings.isLockEnabled = $0 })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(appLock.biometryName) kilidi")
                            .font(.sd.bodyItem)
                            .foregroundStyle(Color.text.primary)
                        Text("Uygulama her açılışta kilitli")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                }
                Toggle(isOn: Binding(get: { settings.hidesContentInSwitcher },
                                     set: { settings.hidesContentInSwitcher = $0 })) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Arka planda gizle")
                            .font(.sd.bodyItem)
                            .foregroundStyle(Color.text.primary)
                        Text("Uygulama değiştiricide ekranı bulanıklaştır")
                            .font(.sd.meta)
                            .foregroundStyle(Color.text.muted)
                    }
                }
            }
        }
    }

    /// Seçim kilit kararından bağımsız: iki bitiş yolu da bu anahtarı okur, yoksa
    /// Face ID'yi açan kullanıcı örnek veriyi hiç göremiyordu.
    private var sampleDataCard: some View {
        Card {
            Toggle(isOn: $wantsSampleData) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Örnek veriyle gez")
                        .font(.sd.bodyItem)
                        .foregroundStyle(Color.text.primary)
                    Text("\(SampleLedger.transactionCount) örnek işlem, bir örnek hesap ve iki bütçe yüklenir. Ayarlar'dan tek dokunuşla silinir.")
                        .font(.sd.meta)
                        .foregroundStyle(Color.text.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func finish() async {
        // Yazma bitmeden ekran değişirse Dashboard boş defteri okuyup boş durumu
        // çiziyor; sıra bilerek yükleme → bayrak → geçiş.
        isFinishing = true
        if wantsSampleData { await loadSampleData() }
        settings.hasCompletedOnboarding = true
        onFinished()
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Text("\(number)")
                .font(.sd.caption)
                .foregroundStyle(Color.text.onBrand)
                .frame(width: 22, height: 22)
                .background(Color.brand.primary, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.sd.bodyItem)
                    .foregroundStyle(Color.text.primary)
                Text(detail)
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func page<Body: View, Actions: View>(
        header: some View,
        title: String,
        message: String,
        @ViewBuilder body: () -> Body,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header
                Text(title)
                    .font(.sd.titleScreen)
                    .foregroundStyle(Color.text.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.sd.meta)
                    .foregroundStyle(Color.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                body()
                VStack(spacing: Spacing.s) { actions() }
                Text("Çevrimdışı · Hesap yok · Veri paylaşımı yok")
                    .font(.sd.caption)
                    .foregroundStyle(Color.text.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(Spacing.l)
            .padding(.bottom, 40)
        }
    }
}
