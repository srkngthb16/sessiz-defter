import Core
import DesignSystem
import SwiftUI

/// A4 — kilit ekranı. Başarılı doğrulamada çapraz geçişle dashboard'a açılır.
public struct LockView: View {
    let appLock: any AppLocking
    let onUnlocked: () -> Void

    @State private var isAuthenticating = false
    @State private var lastError: AppLockError?

    public init(appLock: any AppLocking = SystemAppLock(),
                onUnlocked: @escaping () -> Void) {
        self.appLock = appLock
        self.onUnlocked = onUnlocked
    }

    public var body: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.brand.primary)
            Text("Sessiz Defter kilitli")
                .font(.sd.titleScreen)
                .foregroundStyle(Color.text.primary)
            Text("Devam etmek için \(appLock.biometryName) ile kimliğinizi doğrulayın. Veriler kilitliyken şifreli kalır.")
                .font(.sd.meta)
                .foregroundStyle(Color.text.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if lastError != nil {
                Text("Doğrulanamadı. Tekrar deneyin.")
                    .font(.sd.meta)
                    .foregroundStyle(Color.finance.critical)
            }
            PrimaryButton("Kilidi aç", systemImage: "faceid") { authenticate() }
                .frame(maxWidth: 260)
            Spacer()
            Text("Çevrimdışı · veri paylaşımı yok")
                .font(.sd.caption)
                .foregroundStyle(Color.text.muted)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.canvas)
        .task { authenticate() }
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            let result = await appLock.authenticate(
                reason: "Sessiz Defter'i açmak için kimliğinizi doğrulayın")
            isAuthenticating = false
            switch result {
            case .success:
                lastError = nil
                onUnlocked()
            case .failure(let error):
                // Kullanıcı iptal ettiyse hata gösterme; kilit ekranı zaten duruyor.
                lastError = error == .cancelled ? nil : error
            }
        }
    }
}
