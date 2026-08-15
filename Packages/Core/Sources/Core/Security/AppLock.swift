import Foundation
import LocalAuthentication

/// A3/A4 — tek koruma Face ID, yedeği cihaz parolası. Hesap, şifre, sunucu yok.
public protocol AppLocking: Sendable {
    var isBiometryAvailable: Bool { get }
    var biometryName: String { get }
    func authenticate(reason: String) async -> Result<Void, AppLockError>
}

public enum AppLockError: Error, Equatable, Sendable {
    case cancelled
    case unavailable
    case failed
}

public struct SystemAppLock: AppLocking {
    public init() {}

    public var isBiometryAvailable: Bool {
        // deviceOwnerAuthentication: biyometri yoksa cihaz parolası da kabul edilir.
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    public var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "cihaz parolası"
        }
    }

    public func authenticate(reason: String) async -> Result<Void, AppLockError> {
        let context = LAContext()
        context.localizedFallbackTitle = "iPhone parolasını kullan"
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return .failure(.unavailable)
        }
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                             localizedReason: reason)
            return .success(())
        } catch let error as LAError where error.code == .userCancel
                                        || error.code == .appCancel
                                        || error.code == .systemCancel {
            return .failure(.cancelled)
        } catch {
            return .failure(.failed)
        }
    }
}
