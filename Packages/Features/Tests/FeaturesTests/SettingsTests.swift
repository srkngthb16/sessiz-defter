import Core
import Domain
import Foundation
import Testing
@testable import Features

@Suite("Ayarlar ve kilit")
struct SettingsTests {
    static func freshDefaults() -> UserDefaults {
        let name = "SessizDefterTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @MainActor
    @Test("Varsayılanlar: kilit kapalı, arka planda gizleme açık")
    func varsayilanlar() {
        let settings = AppSettings(defaults: Self.freshDefaults())
        #expect(settings.isLockEnabled == false)
        #expect(settings.hidesContentInSwitcher == true)
        #expect(settings.autoLockDelay == .oneMinute)
        #expect(settings.appearance == .system)
        #expect(settings.hasCompletedOnboarding == false)
    }

    @MainActor
    @Test("Tercihler kalıcı yazılır")
    func kaliciTercihler() {
        let defaults = Self.freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.isLockEnabled = true
        settings.autoLockDelay = .fiveMinutes
        settings.appearance = .dark
        settings.hasCompletedOnboarding = true

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.isLockEnabled)
        #expect(reloaded.autoLockDelay == .fiveMinutes)
        #expect(reloaded.appearance == .dark)
        #expect(reloaded.hasCompletedOnboarding)
    }

    @Test("Silme onayı tam kelime ister")
    func silmeOnayi() {
        #expect(DeleteEverythingView.requiredWord == "SİL")
        // Karşılaştırma birebir: küçük harf ya da noktasız I kabul edilmemeli.
        #expect("sil" != DeleteEverythingView.requiredWord)
        #expect("SIL" != DeleteEverythingView.requiredWord)
    }
}

/// Testte gerçek biyometri yok; kilit akışı sahte doğrulayıcıyla sürülür.
struct StubAppLock: AppLocking {
    let succeeds: Bool
    var isBiometryAvailable: Bool { true }
    var biometryName: String { "Face ID" }

    func authenticate(reason: String) async -> Result<Void, AppLockError> {
        succeeds ? .success(()) : .failure(.failed)
    }
}
