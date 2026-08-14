import Foundation
import Testing

/// Tasarımın katı düzen kuralları kaynak taramasıyla korunur: hiçbir metin
/// .fixedSize() ile dondurulmaz, sabit yükseklikli satır yoktur.
@Suite("Düzen kuralları")
struct LayoutRuleTests {
    /// Yasak olan, metni her iki eksende donduran biçim. `fixedSize(horizontal: false,
    /// vertical: true)` bunun tersini yapar — metnin sarıp uzamasına izin verir — ve serbesttir.
    static let yasakBicimler = [".fixedSize()", ".fixedSize(horizontal: true"]

    @Test("DesignSystem kaynaklarında metin her iki eksende dondurulmuyor")
    func fixedSizeYok() throws {
        let root = try Self.sourcesDirectory()
        let files = try FileManager.default.subpathsOfDirectory(atPath: root.path)
            .filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty)

        for file in files {
            let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false)
                .enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//") else { continue }
                guard Self.yasakBicimler.contains(where: trimmed.contains) else { continue }
                Issue.record("\(file):\(index + 1) metni donduruyor: \(trimmed)")
            }
        }
    }

    static func sourcesDirectory() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // DesignSystemTests
        url.deleteLastPathComponent() // Tests
        url.deleteLastPathComponent() // paket kökü
        return url.appendingPathComponent("Sources/DesignSystem")
    }
}
