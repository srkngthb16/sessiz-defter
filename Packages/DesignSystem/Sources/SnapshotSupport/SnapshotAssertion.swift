import SwiftUI
import UIKit

public struct SnapshotFailure: Error, CustomStringConvertible {
    public let description: String
}

public enum Snapshot {
    /// Referans klasörü test dosyasının yanındaki __Snapshots__/<süit>/ altındadır.
    @MainActor
    public static func verify<V: View>(
        _ view: V,
        name: String,
        suite: String,
        variants: [SnapshotVariant] = SnapshotVariant.dortVaryant,
        size: CGSize = SnapshotDevice.iPhone15Pro,
        testFilePath: String = #filePath
    ) throws {
        var hatalar: [String] = []
        for variant in variants {
            let image = SnapshotRenderer.image(of: view, variant: variant, size: size)
            let url = referenceURL(testFilePath: testFilePath, suite: suite,
                                   name: "\(name).\(variant.name)")
            switch SnapshotComparator.compare(image, referenceURL: url) {
            case .eslesti, .kaydedildi:
                continue
            case .referansYok(let path):
                hatalar.append("Referans yoktu, yazıldı — tekrar çalıştırın: \(path)")
            case .farkli(let mesaj, let farkPath):
                hatalar.append("[\(name).\(variant.name)] \(mesaj)" +
                               (farkPath.map { " · fark: \($0)" } ?? ""))
            }
        }
        guard hatalar.isEmpty else {
            throw SnapshotFailure(description: hatalar.joined(separator: "\n"))
        }
    }

    static func referenceURL(testFilePath: String, suite: String, name: String) -> URL {
        URL(fileURLWithPath: testFilePath)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent(suite)
            .appendingPathComponent("\(name).png")
    }
}
