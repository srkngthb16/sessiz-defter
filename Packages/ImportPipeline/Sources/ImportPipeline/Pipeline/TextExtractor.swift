import Foundation
import PDFKit
import Vision

public enum ImportError: Error, Equatable, Sendable {
    case fileUnreadable
    /// C6 — parola korumalı PDF.
    case passwordProtected
    /// C8 — metin katmanı yok, OCR gerekiyor.
    case noTextLayer
    /// C7 — metin okundu ama bilinen şablona uymuyor.
    case unknownFormat(preview: [String])
    case ocrFailed
}

public struct ExtractedText: Sendable {
    public let text: String
    public let pageCount: Int
    public let usedOCR: Bool

    public init(text: String, pageCount: Int, usedOCR: Bool) {
        self.text = text
        self.pageCount = pageCount
        self.usedOCR = usedOCR
    }
}

public protocol TextExtracting: Sendable {
    /// Parola gerekiyorsa `passwordProtected`, metin katmanı yoksa `noTextLayer` atar.
    func extract(fileAt url: URL, password: String?) throws -> ExtractedText
    /// C8 — kullanıcı onayıyla cihaz üzerinde OCR. Görüntü cihazdan çıkmaz.
    func extractWithOCR(fileAt url: URL, password: String?) async throws -> ExtractedText
}

public struct PDFTextExtractor: TextExtracting {
    /// Bu uzunluğun altındaki metin, taranmış sayfanın kenar yazılarından ibarettir.
    public static let minimumUsefulCharacters = 40

    public init() {}

    public func extract(fileAt url: URL, password: String?) throws -> ExtractedText {
        guard let document = PDFDocument(url: url) else { throw ImportError.fileUnreadable }
        if document.isEncrypted {
            guard let password, document.unlock(withPassword: password) else {
                throw ImportError.passwordProtected
            }
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            pages.append(document.page(at: index)?.string ?? "")
        }
        let text = pages.joined(separator: "\n")
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count
                >= Self.minimumUsefulCharacters else {
            throw ImportError.noTextLayer
        }
        return ExtractedText(text: text, pageCount: document.pageCount, usedOCR: false)
    }

    public func extractWithOCR(fileAt url: URL, password: String?) async throws -> ExtractedText {
        guard let document = PDFDocument(url: url) else { throw ImportError.fileUnreadable }
        if document.isEncrypted {
            guard let password, document.unlock(withPassword: password) else {
                throw ImportError.passwordProtected
            }
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            // 2x ölçek: ekstre punto küçük, 1x'te tanıma hatası artıyor.
            let image = page.thumbnail(of: CGSize(width: bounds.width * 2,
                                                  height: bounds.height * 2),
                                       for: .mediaBox)
            guard let cgImage = image.cgImage else { continue }
            pages.append(try Self.recognizeText(in: cgImage))
        }
        let text = pages.joined(separator: "\n")
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.ocrFailed
        }
        return ExtractedText(text: text, pageCount: document.pageCount, usedOCR: true)
    }

    static func recognizeText(in image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false // tutar ve kod alanlarını bozuyor
        request.recognitionLanguages = ["tr-TR", "en-US"]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        guard let observations = request.results else { return "" }
        // Satır düzeni korunmalı: sütunlar boşlukla hizalı okunuyor.
        return observations
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
