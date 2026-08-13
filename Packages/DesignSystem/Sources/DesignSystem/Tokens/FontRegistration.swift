import CoreText
import Foundation
import UIKit

/// Fontlar paket bundle'ından çalışma anında kaydedilir. Info.plist/UIAppFonts yolu
/// yalnızca uygulama bundle'ı için çalışır; SPM modülü ve snapshot testleri de aynı
/// fontları görmek zorunda olduğu için kayıt kod tarafında yapılır.
public enum Fonts {
    public static let bundledFileNames = [
        "Archivo-Regular", "Archivo-Medium", "Archivo-SemiBold", "Archivo-Bold",
        "IBMPlexMono-Regular", "IBMPlexMono-Medium", "IBMPlexMono-SemiBold"
    ]

    /// Lazy static let tam olarak bir kez ve iş parçacığı güvenli çalışır;
    /// ayrı bir kilit ya da nonisolated(unsafe) değişken gerekmez.
    private static let registrationResult: Bool = performRegistration()

    /// Uygulama açılışında ve snapshot testlerinin setUp'ında çağrılır. Tekrar çağrılması zararsız.
    @discardableResult
    public static func register() -> Bool { registrationResult }

    private static func performRegistration() -> Bool {
        var allSucceeded = true
        for name in bundledFileNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf") else {
                allSucceeded = false
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Zaten kayıtlıysa hata döner; bu bir başarısızlık değil.
                let code = error.map { CFErrorGetCode($0.takeUnretainedValue()) }
                if code != CTFontManagerError.alreadyRegistered.rawValue {
                    allSucceeded = false
                }
            }
        }
        return allSucceeded
    }
}
