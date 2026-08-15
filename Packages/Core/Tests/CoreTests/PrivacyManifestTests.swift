import Foundation
import Testing

/// Gizlilik manifesti App Store'un zorunlu tuttuğu beyandır ve sessizce
/// değişmemeli: izleme kapalı, toplanan veri yok, yalnızca UserDefaults erişimi
/// gerekçelendirilmiş durumda.
@Suite("Gizlilik manifesti")
struct PrivacyManifestTests {
    static func manifest() throws -> [String: Any] {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { url.deleteLastPathComponent() }   // .../Packages/Core/Tests/CoreTests/dosya
        let manifestURL = url.appendingPathComponent("App/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: manifestURL)
        let plist = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test("Geçerli plist olarak ayrıştırılıyor")
    func ayristirilabilir() throws {
        let manifest = try Self.manifest()
        #expect(manifest.isEmpty == false)
    }

    @Test("İzleme kapalı ve izleme alan adı yok")
    func izlemeYok() throws {
        let manifest = try Self.manifest()
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
    }

    @Test("Toplanan veri türü bildirilmiyor")
    func veriToplanmiyor() throws {
        let manifest = try Self.manifest()
        let collected = manifest["NSPrivacyCollectedDataTypes"] as? [Any]
        #expect(collected?.isEmpty == true)
    }

    @Test("Yalnızca UserDefaults erişimi, CA92.1 gerekçesiyle")
    func erisimGerekceleri() throws {
        let manifest = try Self.manifest()
        let accessed = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        #expect(accessed.count == 1)

        let entry = try #require(accessed.first)
        #expect(entry["NSPrivacyAccessedAPIType"] as? String
                == "NSPrivacyAccessedAPICategoryUserDefaults")
        #expect(entry["NSPrivacyAccessedAPITypeReasons"] as? [String] == ["CA92.1"])
    }
}
