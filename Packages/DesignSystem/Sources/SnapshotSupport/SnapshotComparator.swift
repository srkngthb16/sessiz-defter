import UIKit

public enum SnapshotOutcome: Sendable, Equatable {
    case eslesti
    case kaydedildi(path: String)
    case referansYok(path: String)
    case farkli(mesaj: String, farkPath: String?)
}

public enum SnapshotComparator {
    /// Piksel başına kanal farkı bu eşiği aşarsa piksel "farklı" sayılır.
    /// Sıfır tolerans, aynı simülatörde bile font rasterizasyon gürültüsünde patlar.
    public static let kanalToleransi: Int = 6
    /// Farklı piksellerin toplam piksele oranı bu değeri aşarsa test düşer.
    public static let pikselOraniToleransi: Double = 0.002

    public static func compare(_ image: UIImage, referenceURL: URL) -> SnapshotOutcome {
        let kayitModu = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"] == "1"
        guard let png = image.pngData() else {
            return .farkli(mesaj: "PNG üretilemedi", farkPath: nil)
        }

        if kayitModu || !FileManager.default.fileExists(atPath: referenceURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: referenceURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                try png.write(to: referenceURL)
            } catch {
                return .farkli(mesaj: "Referans yazılamadı: \(error)", farkPath: nil)
            }
            return kayitModu ? .kaydedildi(path: referenceURL.path)
                             : .referansYok(path: referenceURL.path)
        }

        guard let referenceData = try? Data(contentsOf: referenceURL),
              let reference = UIImage(data: referenceData) else {
            return .farkli(mesaj: "Referans okunamadı", farkPath: nil)
        }

        return diff(image, reference, failureURL: referenceURL)
    }

    static func diff(_ lhs: UIImage, _ rhs: UIImage, failureURL: URL) -> SnapshotOutcome {
        guard let a = lhs.cgImage, let b = rhs.cgImage else {
            return .farkli(mesaj: "CGImage alınamadı", farkPath: nil)
        }
        guard a.width == b.width, a.height == b.height else {
            return .farkli(
                mesaj: "Boyut farklı: \(a.width)×\(a.height) ≠ \(b.width)×\(b.height)",
                farkPath: writeFailure(lhs, failureURL))
        }

        guard let pixelsA = rgbaBytes(a), let pixelsB = rgbaBytes(b) else {
            return .farkli(mesaj: "Piksel verisi okunamadı", farkPath: nil)
        }

        var farkliPiksel = 0
        let toplamPiksel = a.width * a.height
        for index in stride(from: 0, to: pixelsA.count, by: 4) {
            for channel in 0..<4 where abs(Int(pixelsA[index + channel]) - Int(pixelsB[index + channel])) > kanalToleransi {
                farkliPiksel += 1
                break
            }
        }

        let oran = Double(farkliPiksel) / Double(toplamPiksel)
        guard oran > pikselOraniToleransi else { return .eslesti }
        return .farkli(
            mesaj: "Farklı piksel oranı \(String(format: "%.4f", oran)) > \(pikselOraniToleransi)",
            farkPath: writeFailure(lhs, failureURL))
    }

    private static func writeFailure(_ image: UIImage, _ referenceURL: URL) -> String? {
        guard let png = image.pngData() else { return nil }
        let url = referenceURL.deletingPathExtension().appendingPathExtension("failed.png")
        try? png.write(to: url)
        return url.path
    }

    private static func rgbaBytes(_ image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}
