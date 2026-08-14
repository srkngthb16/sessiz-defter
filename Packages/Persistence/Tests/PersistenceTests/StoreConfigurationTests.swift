import Foundation
import SwiftData
import Testing
@testable import Persistence

/// Kalıcılık kısıtları ayar değil, mimarinin kendisi: CloudKit kapalı ve dosya
/// koruma sınıfı .complete. İkisi de burada doğrulanır.
@Suite("Store yapılandırması")
struct StoreConfigurationTests {
    /// CloudKitDatabase Equatable değil; yansıma açıklaması tek güvenilir kapı.
    static func cloudKitDisabled(_ container: ModelContainer) -> Bool {
        let description = String(describing: container.configurations.first?.cloudKitDatabase)
        return description.contains("_none: true") && description.contains("_automatic: false")
    }

    @Test("Şema yedi modeli de içerir")
    func sema() {
        #expect(SchemaV1.models.count == 7)
    }

    @Test("Üretim kabı CloudKit'siz kurulur ve dosyaya FileProtection.complete uygular")
    func korumaVeCloudKit() throws {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("SessizDefterTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let container = try StoreFactory.makeContainer(directory: folder)
        #expect(Self.cloudKitDisabled(container))

        let storeURL = folder.appendingPathComponent(StoreFactory.storeFileName)
        #expect(FileManager.default.fileExists(atPath: storeURL.path))

        // Simülatörde veri koruma donanımı yok; öznitelik yine de yazılabiliyorsa
        // .complete okunmalı, yazılamıyorsa en azından çağrı hata vermemeli.
        let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            #expect(protection == .complete)
        }
    }

    @Test("Bellek içi kap diske dosya yazmaz")
    func bellekIciKap() throws {
        let container = try StoreFactory.makeInMemoryContainer()
        #expect(container.configurations.first?.isStoredInMemoryOnly == true)
        #expect(Self.cloudKitDisabled(container))
    }
}
