import Core
import DesignSystem
import Domain
import SwiftUI

/// Açılış akışı: onboarding (A1–A3) · kilit (A4) · uygulama.
/// Arka plana alındığında ekran maskelenir — App Switcher'da bakiye görünmemeli.
public struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase

    let environment: AppEnvironment
    let settings: AppSettings
    let appLock: any AppLocking
    let backup: (any BackupServing)?

    @State private var isUnlocked = false
    @State private var isMasked = false
    @State private var backgroundedAt: Date?

    public init(environment: AppEnvironment, settings: AppSettings,
                appLock: any AppLocking = SystemAppLock(),
                backup: (any BackupServing)? = nil) {
        self.environment = environment
        self.settings = settings
        self.appLock = appLock
        self.backup = backup
    }

    public var body: some View {
        ZStack {
            content
            if isMasked { maskOverlay }
        }
        .preferredColorScheme(colorScheme)
        .onChange(of: scenePhase) { _, phase in handle(phase) }
    }

    @ViewBuilder
    private var content: some View {
        if !settings.hasCompletedOnboarding {
            OnboardingView(settings: settings, appLock: appLock,
                           loadSampleData: { try? await SampleData.load(into: environment) }) {
                isUnlocked = true
            }
        } else if settings.isLockEnabled && !isUnlocked {
            LockView(appLock: appLock) {
                withAnimation(.easeInOut(duration: 0.25)) { isUnlocked = true }
            }
            .transition(.opacity)
        } else {
            RootTabView(environment: environment, settings: settings, backup: backup)
                .transition(.opacity)
        }
    }

    /// Maskede içerik değil yalnızca zemin ve marka çizilir.
    private var maskOverlay: some View {
        Color.bg.canvas
            .overlay {
                Image(systemName: "book.closed")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.brand.primary)
            }
            .ignoresSafeArea()
    }

    private var colorScheme: ColorScheme? {
        switch settings.colorScheme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isMasked = false
            relockIfNeeded()
        case .inactive, .background:
            isMasked = settings.hidesContentInSwitcher
            if backgroundedAt == nil { backgroundedAt = Date() }
        @unknown default:
            break
        }
    }

    /// Otomatik kilit: arka planda geçen süre eşiği aşarsa yeniden kilitlenir.
    private func relockIfNeeded() {
        defer { backgroundedAt = nil }
        guard settings.isLockEnabled, let backgroundedAt else { return }
        let elapsed = Date().timeIntervalSince(backgroundedAt)
        if elapsed >= Double(settings.autoLockDelay.rawValue) {
            isUnlocked = false
        }
    }
}
