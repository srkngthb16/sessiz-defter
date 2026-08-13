import Foundation
import Testing

/// Domain katmanı yalnızca Repository protokollerini bilir; kalıcılık ve sunum
/// framework'lerini import etmesi katman ayrımını çöker ve testi imkânsızlaştırır.
@Suite("Katman kuralları")
struct ArchitectureTests {
    static let yasakliImportlar = ["SwiftData", "SwiftUI", "UIKit", "CoreData", "PDFKit", "Vision"]

    @Test("Domain kaynakları kalıcılık/sunum framework'ü import etmez")
    func domainImportlariTemiz() throws {
        let sources = try Self.domainSourcesDirectory()
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: sources.path)
            .filter { $0.hasSuffix(".swift") }

        #expect(!files.isEmpty, "Domain kaynak dosyası bulunamadı: \(sources.path)")

        for file in files {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let module = String(trimmed.dropFirst("import ".count))
                    .trimmingCharacters(in: .whitespaces)
                #expect(
                    !Self.yasakliImportlar.contains(module),
                    "Domain/\(file) yasaklı modülü import ediyor: \(module)"
                )
            }
        }
    }

    static func domainSourcesDirectory() throws -> URL {
        // .../Domain/Tests/DomainTests/ArchitectureTests.swift → .../Domain/Sources/Domain
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // DomainTests
        url.deleteLastPathComponent() // Tests
        url.deleteLastPathComponent() // Domain (paket kökü)
        return url.appendingPathComponent("Sources/Domain")
    }
}
