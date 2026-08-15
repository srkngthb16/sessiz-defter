import Foundation
import Testing
@testable import Features

@Suite("Sürüm bilgisi")
struct AppVersionTests {
    @Test("Sürüm ve build birlikte gösterilir")
    func gosterim() {
        #expect(AppVersion(marketing: "1.0.0", build: "12").displayString == "1.0.0 (12)")
    }

    @Test("Bundle anahtarları okunamazsa çizgi döner, çökmez")
    func eksikAnahtar() {
        let version = AppVersion(bundle: Bundle(for: EmptyMarker.self))
        #expect(version.marketing.isEmpty == false)
        #expect(version.displayString.isEmpty == false)
    }

    @Test("Build bilinmiyorsa yalnız sürüm yazılır")
    func buildYok() {
        #expect(AppVersion(marketing: "1.0.0", build: "—").displayString == "1.0.0")
    }
}

private final class EmptyMarker {}
